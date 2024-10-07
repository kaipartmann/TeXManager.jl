using TeXManager
using Documenter

DocMeta.setdocmeta!(TeXManager, :DocTestSetup, :(using TeXManager); recursive=true)

makedocs(;
    modules=[TeXManager],
    authors="Kai Partmann",
    sitename="TeXManager.jl",
    format=Documenter.HTML(;
        canonical="https://kaipartmann.github.io/TeXManager.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/kaipartmann/TeXManager.jl",
    devbranch="main",
)
