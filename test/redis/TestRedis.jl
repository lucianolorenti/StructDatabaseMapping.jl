module TestRedis
using Pukeko  # @test, @test_throws
using Redis
using StructDatabaseMapping
using Dates


DB_NUMBER = 0
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
    try
        rm(DB_FILE)
    catch
    end
end
function test_redis()
    @info get(ENV, "REDIS_HOST", "localhost")
    @info get(ENV, "REDIS_PORT", 6379)
    mapper = DBMapper(()->Redis.RedisConnection(
        host=get(ENV, "REDIS_HOST", "localhost"),
        db=DB_NUMBER,
        port=get(ENV, "REDIS_PORT", 6379)))

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


    book = Book("super_string_id", author)
    insert!(mapper, book)

    a = select_one(mapper, Book, id="bbb")
    @test isnothing(a)
    a = select_one(mapper, Book, id="super_string_id")
    @test getid(a, mapper) == "super_string_id"
    @test get(a.author, mapper).name == "pirulo"

    

    clean_table!(mapper, Author)
    clean_table!(mapper, Book)

    drop_table!(mapper, Author)
    drop_table!(mapper, Book)


end

end
