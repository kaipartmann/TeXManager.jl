module TeXManager

using ArgParse
using Dates
using REPL.TerminalMenus
using Printf

struct LaTeXCommand
    command::String
    position::UnitRange{Int}
    arg::String
    argposition::UnitRange{Int}
end

struct FileLink{T}
    path::String
    name::String
    realpath::String
    position::UnitRange{Int}
    file::T
end

struct LaTeXFile
    path::String
    text::String
    comment_positions::Vector{UnitRange{Int}}
    labels::Vector{LaTeXCommand}
    graphics::Vector{LaTeXCommand}
    bibs::Vector{LaTeXCommand}
    linked_tex_files::Vector{FileLink{LaTeXFile}}
end

function LaTeXFile(raw_path)
    path = realpath(raw_path)
    if !endswith(path, ".tex")
        error("File $path is no LaTeX file!\n")
    end
    text = read(path, String)
    cmt_positions = comment_positions(text)
    labels = get_cmds(text, cmt_positions, "label"; options=false)
    graphics = get_cmds(text, cmt_positions, "includegraphics"; options=true)
    bibs = get_cmds(text, cmt_positions, "addbibresource"; options=false)
    linked_tex_files = find_linked_tex_files(text, cmt_positions)
    tex_file = LaTeXFile(path, text, cmt_positions, labels, graphics, bibs,
                         linked_tex_files)
    return tex_file
end

function find_linked_tex_files(text::AbstractString,
                               comment_positions::Vector{UnitRange{Int}})
    cmds = Vector{LaTeXCommand}()
    get_cmds!(cmds, text, comment_positions, "include"; options=false)
    get_cmds!(cmds, text, comment_positions, "input"; options=false)
    linked_tex_files = Vector{FileLink{LaTeXFile}}()
    for cmd in cmds
        specified_path = cmd.arg
        name = basename(specified_path)
        real_path = realpath(specified_path)
        tex_file = LaTeXFile(real_path)
        link = FileLink(specified_path, name, real_path, cmd.argposition, tex_file)
        push!(linked_tex_files, link)
    end
    return linked_tex_files
end

function comment_positions(text::AbstractString)::Vector{UnitRange{Int}}
    comment_positions = findall(r"%.+?(?=\n)", text)
    isnothing(comment_positions) && return Vector{UnitRange{Int}}()
    return comment_positions
end
comment_positions(tex_file::LaTeXFile) = comment_positions(tex_file.text)

function is_no_comment(position::UnitRange{Int}, comment_positions::Vector{UnitRange{Int}})
    startindex = first(position)
    for comment_position in comment_positions
        startindex in comment_position && return false
    end
    return true
end

function filter_comments(all_positions, comment_positions)
    return filter(position -> is_no_comment(position, comment_positions), all_positions)
end

function get_cmds!(cmds::Vector{LaTeXCommand}, text::AbstractString,
                   comment_positions::Vector{UnitRange{Int}}, command::String;
                   options::Bool=true)
    if options
        rgx_str = string("\\\\", strip(command), "((.|\\n)*?)\\{((.|\\n)*?)\\}")
    else
        rgx_str = string("\\\\", strip(command), "\\{((.|\\n)*?)\\}")
    end
    all_positions = findall(Regex(rgx_str), text)
    positions = filter_comments(all_positions, comment_positions)
    for position in positions
        arg, argposition = get_arg(text[position])
        push!(cmds, LaTeXCommand(command, position, arg, argposition))
    end
    return nothing
end

function get_cmds(text::AbstractString, comment_positions::Vector{UnitRange{Int}},
                  command::String; options::Bool=true)
    cmds = Vector{LaTeXCommand}()
    get_cmds!(cmds, text, comment_positions, command; options)
    return cmds
end

function get_cmds!(cmds::Vector{LaTeXCommand}, tex_file::LaTeXFile, command::String;
                   options::Bool=true)
    (; text, comment_positions) = tex_file
    get_cmds!(cmds, text, comment_positions, command; options)
    return nothing
end

function get_cmds(tex_file::LaTeXFile, command::String; options::Bool=true)
    cmds = Vector{LaTeXCommand}()
    get_cmds!(cmds, tex_file, command; options)
    return cmds
end

function get_arg(text::AbstractString)
    enclosed = findfirst(r"(?<=\{)(.|\s)+?(?=\})", text)
    isnothing(enclosed) && error("No argument found in given text!")
    innerpos = findfirst(r"(?!\s).*", text[enclosed])
    argposition = first(enclosed)+first(innerpos)-1:first(enclosed)+last(innerpos)-1
    arg = text[argposition]
    return arg, argposition
end

# function find_tex_files(dir::AbstractString)
#     tex_file_paths = filter(x -> endswith(x, ".tex"), readdir(dir, join=true))
#     tex_files = [LaTeXFile(fullpath) for fullpath in tex_file_paths]
#     return tex_files
# end

# function find_preamble(raw_path)
#     path = realpath(raw_path)
#     if !isfile(path)
#         error("no preamble specified!")
#     end
#         preamble = LaTeXFile(path)
#     all_tex_files = find_tex_files(dir)
#     preamble_flag = zeros(Bool, length(all_tex_files))
#     for (i, tex_file) in enumerate(all_tex_files)
#         preamble_flag[i] = is_preamble(tex_file)
#     end
#     preamble_finds = findall(preamble_flag)
#     n_preamble_finds = length(preamble_finds)
#     if n_preamble_finds == 0
#         error("No preamble found! check directory!")
#     end
#     if n_preamble_finds > 1
#         error("More than one preamble found! check directory!")
#     end
#     preamble = all_tex_files[first(preamble_finds)]
#     return preamble
# end

# function is_preamble(tex_file::LaTeXFile)
#     all_positions = findall(r"\\documentclass((.|\n)*?)\{((.|\n)*?)\}", text)
#     isnothing(all_positions) && return false
#     positions = filter_comments(all_positions, comment_positions)
#     return length(positions) > 0 ? true : false
# end

function check_if_labels_are_referenced(tex_file::LaTeXFile)
    all_labels = copy(tex_file.labels)
    all_references = Vector{LaTeXCommand}()
    find_ref_cmds!(all_references, tex_file)
    for link_ in tex_file.linked_tex_files
        for label_ in link_.file.labels
            push!(all_labels, label_)
        end
        find_ref_cmds!(all_references, link_.file)
        for link__ in link_.file.linked_tex_files
            for label__ in link__.file.labels
                push!(all_labels, label__)
            end
            find_ref_cmds!(all_references, link__.file)
            for link___ in link__.file.linked_tex_files
                for label___ in link___.file.labels
                    push!(all_labels, label___)
                end
                find_ref_cmds!(all_references, link___.file)
            end
        end
    end

    for label in all_labels
        label_str = label.arg
        label_refs_idxs = findall(x -> x.arg == label_str, all_references)
        if isempty(label_refs_idxs)
            print_label_warning(label_str)
        elseif length(label_refs_idxs) == 1
            label_ref = all_references[first(label_refs_idxs)]
            refstartpos = label_ref.position
            if refstartpos in label.position
                print_label_warning(label_str)
            end
        end
    end

    return nothing
end

function print_label_warning(label::AbstractString)
    printstyled("WARNING: "; color=:red, bold=true)
    print("label ", label, " not referenced!\n")
    return nothing
end

function find_ref_cmds!(cmds::Vector{LaTeXCommand}, tex_file::LaTeXFile)
    get_cmds!(cmds, tex_file, "ref"; options=false)
    get_cmds!(cmds, tex_file, "ref*"; options=false)
    get_cmds!(cmds, tex_file, "eqref"; options=false)
    get_cmds!(cmds, tex_file, "equationref"; options=false)
    get_cmds!(cmds, tex_file, "autoref"; options=false)
    return nothing
end

function main()
    s = ArgParseSettings("TeXManager - manage LaTeX-projects.")
    @add_arg_table! s begin
        "document"
        required = true
        arg_type = String
        help = "The LaTeX document main file"
    end
    parsed_args = parse_args(ARGS, s)

    println("="^80)
    println("TeXManager.jl")
    println("Copyright © 2024 Kai Partmann. All rights reserved.")
    println("="^80)
    tex_file = LaTeXFile(parsed_args["document"])
    # println(tex_file.text[1:end])
    # for graphics in tex_file.graphics
    #     println("  Graphics: ", graphics.arg)
    # end
    # for link in tex_file.linked_tex_files
    #     println(link.name)
    #     # for label in link.file.labels
    #     #     println("  Labels: ", label.arg)
    #     # end
    #     for graphics in link.file.graphics
    #         println("  Graphics: ", graphics.arg)
    #     end
    # end
    check_if_labels_are_referenced(tex_file)

    printstyled("All checks completed.\n"; color=:green)

    return nothing
end

end
