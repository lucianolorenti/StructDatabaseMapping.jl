# Example

## Let's define a model
This is a simple model. There are four new types to introduce: Model, ForeignKey, DBId and Foreign.
* Model is the abstact type every struct to be persisted should inherit from
* ForeignKey is a generic type that represents a reference to other Model
* DBId is other generic type that encodes the struct identifier.
* Foreign is used as datatype in the constructor of a struct that contains a ForeignKey field. That datatype is bit of hack I don't like, but I couldn't find a  better way.

Each `type <: Model` must have a construcor with named parameters.

The DBMapper type is the main type of the library. The mapper is constructed with a function passed as an argument.


```@example code_1
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
nothing # hide
```
First we should create the DBMapper and register our types
```@example code_1
DB_FILE = "test_db"
using SQLite
creator = ()->SQLite.DB(DB_FILE)
mapper = DBMapper(creator)

register!(mapper, Author)
register!(mapper, Book)

@test haskey(mapper.tables, Author)
@test haskey(mapper.tables, Book)

create_table(mapper, Author)
create_table(mapper, Book)
nothing # hide
```

```@example code_1
author = Author(name="pirulo", age=50)
insert!(mapper, author)
@test !isnothing(getid(author, mapper))
println(author)
```

```@example code_1
id = getid(author, mapper)
a = select_one(mapper, Author, id=999)
println(a)
```

```@example code_1
a = select_one(mapper, Author, id=id)
println(a)
```

## Existence
```@example code_1
author = Author(name="Author 1", age=2)
insert!(mapper, author)

author = Author(name="Author 2", age=3)
insert!(mapper, author)

author = Author(name="Author 3", age=4)
insert!(mapper, author)

println(exists(mapper, Author, name="Enrique Banch"))
println(exists(mapper, Author, name="pirulo"))
println(exists(mapper, author))

println(exists(mapper, Author, name="Author 3", age=4))
println(exists(mapper, Author, name="Author 3", age=3))
println(exists(mapper, Author, pk=author.id.x, age=3))
println(exists(mapper, Author, pk=author.id.x, age=4))
```

## Update 
the function `update!` receives a named argument `fields` that indicates the fields to be updated
```@example code_1
a.name = "otro_pirulo"
a.age = 5
update!(mapper, a; fields=[:name])
a = select_one(mapper, Author, id=id)
println(a)
```
If `fields` is omitted all the fields are updated
```@example code_1
a.name = "some_other_name"
a.age = 5
update!(mapper, a)
a = select_one(mapper, Author, id=id)
println(a)
```

# Insert element with foreign key and dict
```@example code_1
book = Book(id="super_string_id", author=author, 
            data=Dict{String, Integer}("some_data"=>5))
insert!(mapper, book)
```

```@example code_1
book = select_one(mapper, Book, id="bbb")
println(book)
```

```@example code_1
book = select_one(mapper, Book, id="super_string_id")
println(book)
```

# Removing tables
```@example code_1
drop_table!(mapper, Author)
drop_table!(mapper, Book)
```
