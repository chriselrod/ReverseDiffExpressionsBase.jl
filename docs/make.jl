using Documenter, ReverseDiffExpressionsBase

makedocs(;
    modules=[ReverseDiffExpressionsBase],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/chriselrod/ReverseDiffExpressionsBase.jl/blob/{commit}{path}#L{line}",
    sitename="ReverseDiffExpressionsBase.jl",
    authors="Chris Elrod <elrodc@gmail.com>",
    assets=String[],
)

deploydocs(;
    repo="github.com/chriselrod/ReverseDiffExpressionsBase.jl",
)
