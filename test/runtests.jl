

module TestQueue
using Pukeko  # @test, @test_throws
using StructDatabaseMapping
const Queue = StructDatabaseMapping.Queue
function test_queue()
    a = Queue(3)
    push!(a, 5)
    push!(a, 5)
    push!(a, 1)
    Pukeko.@test_throws StructDatabaseMapping.Full StructDatabaseMapping.push!_nowait(a, 12)
end
end

module TestPool
using Pukeko  # @test, @test_throws
using StructDatabaseMapping
const Pool = StructDatabaseMapping.QueuePool
struct TestConnection
    a::Integer
end
function test_pool()
    pool = Pool(x->TestConnection(5))

end
end
module TestRelational
using Pukeko  # @test, @test_throws
using StructDatabaseMapping
using Dates



struct Author
    id::DBId{Integer}
    name::String
    date::DateTime
end
function Author(;id::DBId{Integer}=DBId{Integer}(),
                name::String="",
                date::DateTime=now())
    return Author(id, name, date)
end
struct Book
    id::DBId{String}
    author::ForeignKey{Author}
end


function test_register()

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

    mapper = DBMapper(_->SQLite("a"))
    register!(mapper, Author)
    register!(mapper, Book)

    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)

    analyze_relations(mapper)

    @test create_table(mapper, Author) == "CREATE TABLE IF NOT EXISTS author (id INTEGER PRIMARY KEY, name VARCHAR  NOT NULL, date DATETIME  NOT NULL)"
    @test create_table(mapper, Book) == "CREATE TABLE IF NOT EXISTS book (id VARCHAR PRIMARY KEY, author INTEGER  NOT NULL)"

    author = Author(name="pirulo")
    insert!(mapper, author)
end

function test_create_table()
end
end

import Pukeko
Pukeko.run_tests(TestQueue)
Pukeko.run_tests(TestPool)
Pukeko.run_tests(TestRelational)
