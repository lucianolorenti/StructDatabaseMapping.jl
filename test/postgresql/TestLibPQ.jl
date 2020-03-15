
module TestLibPQ
using Test
using LibPQ
using StructDatabaseMapping
using Dates


DB_FILE = "test_db"

include("../includes/basic_test.jl")

host = get(ENV, "POSTGRES_HOST", "localhost")
port = get(ENV, "INPUT_POSTGRES_PORT", 5432)
db_name = get(ENV, "POSTGRES_DB", "sdm_test")
user = get(ENV, "POSTGRES_USER", "luciano")
password = get(ENV, "POSTGRES_PASSWORD", "")
conn_str = "host=$host port=$port user=$user dbname=$db_name"
conn_str = conn_str * (length(password) > 0 ? " password=$password" : "" )
function cleanup()
    conn = LibPQ.Connection(conn_str)
    execute(conn, "DROP TABLE book")
    execute(conn, "DROP TABLE author")

end


function test_create_tables()
    mapper = DBMapper(()->LibPQ.Connection(conn_str))

    register!(mapper, Author)
    register!(mapper, Book)
    configure_relation(mapper, Book, :author, on_delete=Cascade())
    @test (StructDatabaseMapping.create_table_query(mapper, Author)
    == "CREATE TABLE IF NOT EXISTS author (" *
       "age INTEGER NOT NULL, " *
       "country VARCHAR NOT NULL, " *
       "date TIMESTAMP NOT NULL, " *
       "id SERIAL PRIMARY KEY, " *
       "name VARCHAR NOT NULL)")
    @test (StructDatabaseMapping.create_table_query(mapper, Book)
     == "CREATE TABLE IF NOT EXISTS book (" *
         "author_id INTEGER NOT NULL, " *
         "data JSON NOT NULL, " *
         "id VARCHAR PRIMARY KEY, " *
         "title VARCHAR NOT NULL, " *
         "FOREIGN KEY(author_id) REFERENCES author(id) ON DELETE CASCADE ON UPDATE NO ACTION)")
end
function test()
    test_create_tables()
    test_postgres()
end
function test_postgres()
    _test_basic_functionalities(()->LibPQ.Connection(conn_str))
end

end
