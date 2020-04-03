[![Coverage Status](https://coveralls.io/repos/github/lucianolorenti/StructDatabaseMapping.jl/badge.svg)](https://coveralls.io/github/lucianolorenti/StructDatabaseMapping.jl)  [![](https://img.shields.io/badge/docs-dev-blue.svg)](https://lucianolorenti.github.io/StructDatabaseMapping.jl/dev/index.html)

# Installation
```julia
] add StructDatabaseMapping
```



# Compatibility
* [SQLite](https://github.com/JuliaDatabases/SQLite.jl)
* [PostgreSQL](https://github.com/invenia/LibPQ.jl)
* [Redis](https://github.com/JuliaDatabases/Redis.jl)
* Possibly every relational DB that supports the DBInterface


# Simple example
[For a better example see the docs](https://lucianolorenti.github.io/StructDatabaseMapping.jl/dev/example.html)
```julia
using StructDatabaseMapping
using Dates
using SQLite
using Test

mutable struct Author <: Model
    id::DBId{Integer}
    name::String
    age::Integer
    date::DateTime
end
function Author(;id::Union{Integer, Nothing} = nothing,
                name::String="",
                age::Integer=0,
                date::DateTime=now())
    return Author(id, name, age, date)
end
mutable struct Book <: Model
    id::DBId{String}
    author::ForeignKey{Author}
    data::Dict{String, Integer}
end
function Book(;id::Union{String, Nothing}=nothing,
               author::Foreign{Author}=Author(),
               data::Dict{String, Integer}=Dict())
    return Book(id, author, data)
end

DB_FILE = "test_db"
using SQLite
creator = ()->SQLite.DB(DB_FILE)
mapper = DBMapper(creator)

register!(mapper, Author)
register!(mapper, Book)

configure_relation(mapper, Book, :author, on_delete=Cascade())
create_table(mapper, Author)
create_table(mapper, Book)
author = Author(name="pirulo", age=50)
insert!(mapper, author)
```
