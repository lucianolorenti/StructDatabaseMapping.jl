module TestRedis
using Test 
using Redis
using StructDatabaseMapping
using Dates


DB_NUMBER = 0

include("../model.jl")

function test()
    test_redis()
end
function cleanup()
    try
      
    catch
    end
end
function test_redis()
    mapper = DBMapper(()->Redis.RedisConnection(
        host=get(ENV, "REDIS_HOST", "localhost"),
        db=DB_NUMBER,
        port=parse(Int64, get(ENV, "REDIS_PORT", "6379"))))

    register!(mapper, Author)
    register!(mapper, Book)
    
    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)

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
    @test getid(a, mapper) == "super_string_id"
    @test get(a.author, mapper).name == "pirulo"
    @test a.data["some_data"] == 5
    

    clean_table!(mapper, Author)
    clean_table!(mapper, Book)

    drop_table!(mapper, Author)
    drop_table!(mapper, Book)


end

end
