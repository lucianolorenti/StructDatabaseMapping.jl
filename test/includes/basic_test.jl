mutable struct Author <: Model
    id::DBId{Integer}
    name::String
    age::Integer
    date::DateTime
end
function Author(;id::Union{Integer, Nothing} = nothing,
                name::String="",
                age::Integer=0,
                date::DateTime=now())
    return Author(id, name, age, date)
end
mutable struct Book <: Model
    id::DBId{String}
    author::ForeignKey{Author}
    data::Dict{String, Integer}
end
function Book(;id::Union{String, Nothing}=nothing,
               author::Foreign{Author}=Author(),
               data::Dict{String, Integer}=Dict())
    return Book(id, author, data)
end
function _test_basic_functionalities(creator)
    mapper = DBMapper(creator)

    register!(mapper, Author)
    register!(mapper, Book)
    
    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)

    create_table(mapper, Author)
    create_table(mapper, Book)

    author = Author(name="pirulo", age=50)
    insert!(mapper, author)
    @test !isnothing(author.id.x)
    id = author.id.x

    a = select_one(mapper, Author, id=999)
    @test isnothing(a)
    a = select_one(mapper, Author, id=id)
    @test a.name == "pirulo"

    a.name = "otro_pirulo"
    a.age = 5
    update!(mapper, a; fields=[:name])
    a = select_one(mapper, Author, id=id)
    @test a.name == "otro_pirulo"
    @test a.age == 50

    a.name = "some_other_name"
    a.age = 5
    update!(mapper, a)
    a = select_one(mapper, Author, id=id)
    @test a.name == "some_other_name"
    @test a.age == 5

    book = Book(id="super_string_id", author=author, 
                data=Dict{String, Integer}("some_data"=>5))
    insert!(mapper, book)

    a = select_one(mapper, Book, id="bbb")
    @test isnothing(a)
    a = select_one(mapper, Book, id="super_string_id")
    
    @test a.id.x == "super_string_id"
    @test get(a.author, mapper).name == "some_other_name"
    @test a.data["some_data"] == 5



end