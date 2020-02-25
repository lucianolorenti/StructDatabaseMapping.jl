[![Coverage Status](https://coveralls.io/repos/github/lucianolorenti/StructDatabaseMapper/badge.svg?branch=master)](https://coveralls.io/github/lucianolorenti/StructDatabaseMapper?branch=master)

# Installation
```julia
] add https://github.com/lucianolorenti/StructDatabaseMapping.jl.git
```

# Compatibility
* SQLite
* PostgreSQL
* Redis
* Possibly every relational DB that supports the DBInterface

# Let define a model
This is a simple model. There are two different types: ForeignKey and DBId. 
Each of the `struct` has to have a construcor with named parameters.
```julia
using StructDatabaseMapping
using Dates
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
```

First we should create the DBMapper and register our types

```julia
using SQLite
DB_FILE = "test.db"
mapper = DBMapper(()->SQLite.DB(DB_FILE))

register!(mapper, Author)
register!(mapper, Book)
```

Table creation
```julia
create_table(mapper, Author)
create_table(mapper, Book)
``` 
```sql
[ Info: CREATE TABLE IF NOT EXISTS author (id INTEGER PRIMARY KEY, name VARCHAR NOT NULL, age INTEGER NOT NULL, date DATETIME NOT NULL)
[ Info: CREATE TABLE IF NOT EXISTS book (id VARCHAR PRIMARY KEY, author_id INTEGER NOT NULL, data JSON NOT NULL, FOREIGN KEY(author_id) REFERENCES author(id))
```
## Inserting objects
```julia
author = Author(name="pirulo", age=50)
insert!(mapper, author)
```
```sql
┌ Info: INSERT INTO author (name,age,date)
└ VALUES (?,?,?)
Author(DBId{Integer}(1), "pirulo", 50, 2020-02-21T15:52:12.677)
```


```julia
author_selected = select_one(mapper, Author, id=id)
```
```sql
┌ Info: SELECT  id, name, age, date
│ FROM author
│ WHERE id=1
└ LIMIT 1
```

## Updating
```julia
author_selected.name = "otro_pirulo"
author_selected.age = 5
update!(mapper, author_selected; fields=[:name])
a = select_one(mapper, Author, id=id)
author_selected.name == "otro_pirulo"
author_selected.age == 50

author_selecteda.name = "some_other_name"
author_selected.age = 5
update!(mapper, author_selected)
author_selected = select_one(mapper, Author, id=id)
@test author_selected.name == "some_other_name"
@test author_selected.age == 5
```
```sql
 Info: UPDATE author
│ SET name=?
│ WHERE 
└ id = ?
┌ Info: UPDATE author
│ SET name=?,age=?,date=?
│ WHERE 
└ id = ?
```


## Inserting complex data
```julia
book = Book(id="super_string_id", author=author, 
            data=Dict{String, Integer}("some_data"=>5))
insert!(mapper, book)
```
```sql
┌ Info: INSERT INTO book (id,author_id,data)
│ VALUES (?,?,?)
└     
```

## Obtaining foreign objects
```julia
book = select_one(mapper, Book, id="super_string_id")
get(book.author, mapper).name == "pirulo"
book.data["some_data"] == 5
```
```sql
┌ Info: SELECT  id, author_id, data
│ FROM book
│ WHERE id="super_string_id"
└ LIMIT 1
┌ Info: SELECT  id, name, date
│ FROM author
│ WHERE id=1
└ LIMIT 1
```

# Removing tables
```julia
drop_table!(mapper, Author)
drop_table!(mapper, Book)
```
```sql
[ Info: DROP TABLE author
[ Info: DROP TABLE book
```
   
