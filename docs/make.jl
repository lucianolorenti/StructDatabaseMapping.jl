using Documenter, StructDatabaseMapping

makedocs(sitename="Struct Database Mapping",
         pages = ["example.md"])
deploydocs(
            repo = "github.com/lucianolorenti/StructDatabaseMapping.jl.gitt",
        )