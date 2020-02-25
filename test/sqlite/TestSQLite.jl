module TestSQLite
using Test  
using SQLite
using StructDatabaseMapping
using Dates

include("../includes/basic_test.jl")

DB_FILE = "test_db"

function test()
    test_create_tables()
    test_sqlite()
end
function cleanup()
    try
        rm(DB_FILE)
    catch
    end
end
function test_create_tables()
    mapper = DBMapper(()->SQLite.DB(DB_FILE))

    register!(mapper, Author)
    register!(mapper, Book)

    @test (StructDatabaseMapping.create_table_query(mapper, Author) 
    == "CREATE TABLE IF NOT EXISTS author (" *
       "id INTEGER PRIMARY KEY, " *
       "name VARCHAR NOT NULL, " *
       "age INTEGER NOT NULL, " *
       "date DATETIME NOT NULL)")
    @test (StructDatabaseMapping.create_table_query(mapper, Book) 
     == "CREATE TABLE IF NOT EXISTS book (" *
         "id VARCHAR PRIMARY KEY, " *
         "author_id INTEGER NOT NULL, " * 
         "data JSON NOT NULL, " *
         "FOREIGN KEY(author_id) REFERENCES author(id))")
end
function test_sqlite()
   
    _test_basic_functionalities(()->SQLite.DB(DB_FILE))   

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
