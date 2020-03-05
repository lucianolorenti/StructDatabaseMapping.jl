using Documenter, StructDatabaseMapping

makedocs(sitename="Struct Database Mapping",
        format = Documenter.HTML(prettyurls = false),
        modules = [StructDatabaseMapping],
         pages = [ 
            "Home" => "index.md",
            "Api" => "api.md",
            "Example"=>"example.md"]
        )

deploydocs(
    repo="github.com/lucianolorenti/StructDatabaseMapping.jl.git")
