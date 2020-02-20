# Installation

# Let define a model
This is a simple model. There are two different types: ForeignKey and DBId. 
Each of the `struct` has to have a construcor with named parameters.
```julia
struct Author
    id::DBId{Integer}
    name::String
    date::DateTime
end
function Author(;id::Union{Integer, Nothing} = nothing,
                name::String="",
                date::DateTime=now())
    return Author(id, name, date)
end
struct Book
    id::DBId{String}
    author::ForeignKey{Author}
end
function Book(;id::Union{String, Nothing}=nothing,
               author::ForeignKey{Author}=ForeignKey{Author}())
    return Book(id, author)
end
```

```julia
using StructDatabaseMapper
using SQLite
mapper = DBMapper(()->SQLite.DB(DB_FILE))

register!(mapper, Author)
register!(mapper, Book)
```

```julia
create_table(mapper, Author)
create_table(mapper, Book)
``` 

```julia
author = Author(name="pirulo")
insert!(mapper, author)
```

```julia
author_selected = select_one(mapper, Author, id=id)
```

```julia
book = Book("super_string_id", author)
insert!(mapper, book)
get(a.author, mapper).name == "pirulo"
```
