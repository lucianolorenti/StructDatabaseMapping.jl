module TestRelational
using Pukeko  # @test, @test_throws
using SQLite
using LibPQ
using StructDatabaseMapping
using Dates


DB_FILE = "test_db"
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

function test_field()
    field = StructDatabaseMapping.Field(:name, Nullable{String})
    @test field.name == :name
    @test field.nullable == true
    @test field.type == String


    field = StructDatabaseMapping.Field(:name, DBId{Float64})
    @test field.name == :name
    @test field.nullable == true
    @test field.type == Float64
end

function cleanup()
    rm(DB_FILE)
end
function _test_operations(creator)
    mapper = DBMapper(creator)

    register!(mapper, Author)
    register!(mapper, Book)
    
    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)
    
    analyze_relations(mapper)

    @test (StructDatabaseMapping.create_table_query(mapper, Author) 
         == "CREATE TABLE IF NOT EXISTS author (id INTEGER PRIMARY KEY, name VARCHAR  NOT NULL, date DATETIME  NOT NULL)")

    @test (StructDatabaseMapping.create_table_query(mapper, Book) 
          == "CREATE TABLE IF NOT EXISTS book (id VARCHAR PRIMARY KEY, author_id INTEGER  NOT NULL)")

    create_table(mapper, Author)
    create_table(mapper, Book)

    author = Author(name="pirulo")
    insert!(mapper, author)
    @test !isnothing(author.id.x)
    id = author.id.x

    a = select_one(mapper, Author, id=999)
    @test isnothing(a)
    a = select_one(mapper, Author, id=id)
    @test a.name == "pirulo"


    book = Book("super_string_id", author)
    insert!(mapper, book)

    a = select_one(mapper, Book, id="bbb")
    @test isnothing(a)
    a = select_one(mapper, Book, id="super_string_id")
    
    @test a.id.x == "super_string_id"
    @test get(a.author, mapper).name == "pirulo"

    

    clean_table!(mapper, Author)
    clean_table!(mapper, Book)

    drop_table!(mapper, Author)
    drop_table!(mapper, Book)


end


Pukeko.@parametric _test_operations [()->SQLite.DB(DB_FILE),
                                     ()->LibPQ.Connection("dbname=postgres")]
end
