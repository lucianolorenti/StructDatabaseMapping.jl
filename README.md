[![Coverage Status](https://coveralls.io/repos/github/lucianolorenti/StructDatabaseMapper/badge.svg?branch=lucianolorenti-CI)](https://coveralls.io/github/lucianolorenti/StructDatabaseMapper?branch=lucianolorenti-CI)

# Installation
```julia
] add https://github.com/lucianolorenti/StructDatabaseMapper.git
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
struct Author <: Model
    id::DBId{Integer}
    name::String
    date::DateTime
end
function Author(;id::Union{Integer, Nothing} = nothing,
                name::String="",
                date::DateTime=now())
    return Author(id, name, date)
end
struct Book <: Model
    id::DBId{String}
    author::ForeignKey{Author}
end
function Book(;id::Union{String, Nothing}=nothing,
               author::ForeignKey{Author}=ForeignKey{Author}())
    return Book(id, author)
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
[ Info: CREATE TABLE IF NOT EXISTS author (id INTEGER PRIMARY KEY, name VARCHAR  NOT NULL, date DATETIME  NOT NULL)
[ Info: CREATE TABLE IF NOT EXISTS book (id VARCHAR PRIMARY KEY, author_id INTEGER  NOT NULL, FOREIGN KEY(author_id) REFERENCES author(id))
```

```julia
author = Author(name="pirulo")
insert!(mapper, author)
```
```sql
┌ Info: INSERT INTO author (name,date)
│ VALUES (?,?)
└     
Author(DBId{Integer}(1), "pirulo", 2020-02-21T15:52:12.677)
```


```julia
author_selected = select_one(mapper, Author, id=id)
```
```sql
┌ Info: SELECT  id, name, date
│ FROM author
│ WHERE id=1
└ LIMIT 1
```
```julia
book = Book("super_string_id", author)
insert!(mapper, book)
```
```sql
┌ Info: INSERT INTO book (id,author_id)
│ VALUES (?,?)
```
```julia
book = select_one(mapper, Book, id="super_string_id")
get(a.author, mapper).name == "pirulo"
```

```sql
┌ Info: SELECT  id, author_id
│ FROM book
│ WHERE id="super_string_id"
└ LIMIT 1
┌ Info: SELECT  id, name, date
│ FROM author
│ WHERE id=1
└ LIMIT 1
```

```julia
    drop_table!(mapper, Author)
    drop_table!(mapper, Book)
```
```sql
[ Info: DROP TABLE author
[ Info: DROP TABLE book
```


