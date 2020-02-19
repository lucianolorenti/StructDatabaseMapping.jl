module TestRelational
using Pukeko  # @test, @test_throws
using SQLite
using StructDatabaseMapping
using Dates



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

function test_field()
    field = StructDatabaseMapping.Field(:name, Nullable{String})
    @test field.name == :name
    @test field.nullable == true
    @test field.primary_key == false
    @test field.type == String


    field = StructDatabaseMapping.Field(:name, DBId{Float64})
    @test field.name == :name
    @test field.nullable == true
    @test field.primary_key == true
    @test field.type == Float64
end


function test_register()

    

    mapper = DBMapper(()->SQLite.DB("a"))
    register!(mapper, Author)
    register!(mapper, Book)

    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)

    analyze_relations(mapper)

    @test (StructDatabaseMapping.create_table_query(mapper, Author) 
         == "CREATE TABLE IF NOT EXISTS author (id INTEGER PRIMARY KEY, name VARCHAR  NOT NULL, date DATETIME  NOT NULL)")

    @test (StructDatabaseMapping.create_table_query(mapper, Book) 
          == "CREATE TABLE IF NOT EXISTS book (id VARCHAR PRIMARY KEY, author INTEGER  NOT NULL)")

    create_table(mapper, Author)
    create_table(mapper, Book)

    author = Author(name="pirulo")
    insert!(mapper, author)
    @test !isnothing(author.id.x)

    a = select_one(mapper, Author, id=45)
    @test isnothing(a)
    a = select_one(mapper, Author, id=1)
    println(a)
end

function test_create_table()
end
end
