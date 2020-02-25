var documenterSearchIndex = {"docs":
[{"location":"example/#Example-1","page":"Example","title":"Example","text":"","category":"section"},{"location":"example/#Let's-define-a-model-1","page":"Example","title":"Let's define a model","text":"","category":"section"},{"location":"example/#","page":"Example","title":"Example","text":"This is a simple model. There are four new types to introduce: Model, ForeignKey, DBId and Foreign.","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"Model is the abstact type every struct to be persisted should inherit from\nForeignKey is a generic type that represents a reference to other Model\nDBId is other generic type that encodes the struct identifier.\nForeign is used as datatype in the constructor of a struct that contains a ForeignKey field. That datatype is bit of hack I don't like, but I couldn't find a  better way.","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"Each type <: Model must have a construcor with named parameters.","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"using StructDatabaseMapping\nusing Dates\nusing SQLite\nusing Test\n\nmutable struct Author <: Model\n    id::DBId{Integer}\n    name::String\n    age::Integer\n    date::DateTime\nend\nfunction Author(;id::Union{Integer, Nothing} = nothing,\n                name::String=\"\",\n                age::Integer=0,\n                date::DateTime=now())\n    return Author(id, name, age, date)\nend\nmutable struct Book <: Model\n    id::DBId{String}\n    author::ForeignKey{Author}\n    data::Dict{String, Integer}\nend\nfunction Book(;id::Union{String, Nothing}=nothing,\n               author::Foreign{Author}=Author(),\n               data::Dict{String, Integer}=Dict())\n    return Book(id, author, data)\nend\nnothing # hide","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"First we should create the DBMapper and register our types","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"DB_FILE = \"test_db\"\nusing SQLite\ncreator = ()->SQLite.DB(DB_FILE)\nmapper = DBMapper(creator)\n\nregister!(mapper, Author)\nregister!(mapper, Book)\n\n@test haskey(mapper.tables, Author)\n@test haskey(mapper.tables, Book)\n\ncreate_table(mapper, Author)\ncreate_table(mapper, Book)\nnothing # hide","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"author = Author(name=\"pirulo\", age=50)\ninsert!(mapper, author)\n@test !isnothing(getid(author, mapper))\nprintln(author)","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"id = getid(author, mapper)\na = select_one(mapper, Author, id=999)\nprintln(a)","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"a = select_one(mapper, Author, id=id)\nprintln(a)","category":"page"},{"location":"example/#Update-1","page":"Example","title":"Update","text":"","category":"section"},{"location":"example/#","page":"Example","title":"Example","text":"the function update! receives a named argument fields that indicates the fields to be updated","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"a.name = \"otro_pirulo\"\na.age = 5\nupdate!(mapper, a; fields=[:name])\na = select_one(mapper, Author, id=id)\nprintln(a)","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"If fields is omitted all the fields are updated","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"a.name = \"some_other_name\"\na.age = 5\nupdate!(mapper, a)\na = select_one(mapper, Author, id=id)\nprintln(a)","category":"page"},{"location":"example/#Insert-element-with-foreign-key-and-dict-1","page":"Example","title":"Insert element with foreign key and dict","text":"","category":"section"},{"location":"example/#","page":"Example","title":"Example","text":"book = Book(id=\"super_string_id\", author=author, \n            data=Dict{String, Integer}(\"some_data\"=>5))\ninsert!(mapper, book)","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"book = select_one(mapper, Book, id=\"bbb\")\nprintln(book)","category":"page"},{"location":"example/#","page":"Example","title":"Example","text":"book = select_one(mapper, Book, id=\"super_string_id\")\nprintln(book)","category":"page"},{"location":"example/#Removing-tables-1","page":"Example","title":"Removing tables","text":"","category":"section"},{"location":"example/#","page":"Example","title":"Example","text":"drop_table!(mapper, Author)\ndrop_table!(mapper, Book)","category":"page"}]
}
