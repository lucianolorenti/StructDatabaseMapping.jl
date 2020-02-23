
module TestLibPQ
using Pukeko  # @test, @test_throws
using LibPQ
using StructDatabaseMapping
using Dates


DB_FILE = "test_db"
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

function cleanup()
    conn = LibPQ.Connection("host=localhost user=luciano dbname=sdm_test")
    execute(conn, "DROP DATABASE sdm_test")
end
function test_postgres()

    host = get(ENV, "POSTGRES_HOST", "localhost")
    port = get(ENV, "POSTGRES_PORT", 5432)
    db_name = get(ENV, "POSTGRES_DB", "sdm_test")
    user = get(ENV, "POSTGRES_USER", "luciano")
    password = get(ENV, "POSTGRES_PASSWORD", "")
    conn_str = "host=$host port=$port user=$user dbname=$dbname" 
    conn_str = conn_str * (length(password) > 0 : " password=$password" : "" )
    @info conn_str
    mapper = DBMapper(()->LibPQ.Connection(conn_str))

    register!(mapper, Author)
    register!(mapper, Book)
    
    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)

    @test (StructDatabaseMapping.create_table_query(mapper, Author) 
         == "CREATE TABLE IF NOT EXISTS author (id SERIAL PRIMARY KEY, name VARCHAR  NOT NULL, date TIMESTAMP  NOT NULL)")

    @test (StructDatabaseMapping.create_table_query(mapper, Book) 
          == "CREATE TABLE IF NOT EXISTS book (id VARCHAR PRIMARY KEY, author_id INTEGER  NOT NULL, FOREIGN KEY(author_id) REFERENCES author(id))")

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

    
    clean_table!(mapper, Book)
    clean_table!(mapper, Author)
    
    drop_table!(mapper, Book)
    drop_table!(mapper, Author)
    


end

end
