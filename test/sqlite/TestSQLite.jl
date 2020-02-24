module TestSQLite
using Test  
using SQLite
using StructDatabaseMapping
using Dates

include("../model.jl")

DB_FILE = "test_db"

function test()
    test_sqlite()
end
function cleanup()
    try
        rm(DB_FILE)
    catch
    end
end
function test_sqlite()
    mapper = DBMapper(()->SQLite.DB(DB_FILE))

    register!(mapper, Author)
    register!(mapper, Book)
    
    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)

    @test (StructDatabaseMapping.create_table_query(mapper, Author) 
         == "CREATE TABLE IF NOT EXISTS author (id INTEGER PRIMARY KEY, name VARCHAR  NOT NULL, date DATETIME  NOT NULL)")

    @test (StructDatabaseMapping.create_table_query(mapper, Book) 
          == "CREATE TABLE IF NOT EXISTS book (id VARCHAR PRIMARY KEY, author_id INTEGER  NOT NULL, data JSON  NOT NULL, FOREIGN KEY(author_id) REFERENCES author(id))")

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


    book = Book(id="super_string_id", author=author, 
                data=Dict{String, Integer}("some_data"=>5))
    insert!(mapper, book)

    a = select_one(mapper, Book, id="bbb")
    @test isnothing(a)
    a = select_one(mapper, Book, id="super_string_id")
    
    @test a.id.x == "super_string_id"
    @test get(a.author, mapper).name == "pirulo"
    @test a.data["some_data"] == 5



end
function test_cleanup()
    mapper = DBMapper(()->SQLite.DB(DB_FILE))

    register!(mapper, Author)
    register!(mapper, Book)    

    clean_table!(mapper, Author)
    clean_table!(mapper, Book)

    drop_table!(mapper, Author)
    drop_table!(mapper, Book)
end
end
