mutable struct Author <: Model
    id::DBId{Integer}
    name::String
    age::Integer
    country::String
    date::DateTime
end
function Author(;id::Union{Integer, Nothing} = nothing,
                name::String="",
                age::Integer=0,
                country::String="",
                date::DateTime=now())
    return Author(id, name, age, country, date)
end
mutable struct Book <: Model
    id::DBId{String}
    title::String
    author::ForeignKey{Author}
    data::Dict{String, Integer}
end
function Book(;id::Union{String, Nothing}=nothing,
               title::String="",
               author::Foreign{Author}=Author(),
               data::Dict{String, Integer}=Dict())
    return Book(id, title, author, data)
end

function _test_on_delete()
    mapper = DBMapper(creator)
    register!(mapper, Author)
    register!(mapper, Book)
    configure_relation(mapper, Book, :author, on_delete=Cascade())

    author = Author(name="Author 1", age=50)
    insert!(mapper, Author(name="Author 1", age=50))
    insert!(mapper, Author(name="Author 2", age=50))
    insert!(mapper, Author(name="Author 3", age=50))
    insert!(mapper, Author(name="Author 4", age=50))

    author1 = select_one(mapper, Author, name="Author 1")
    author3 = select_one(mapper, Author, name="Author 3")

    insert!(mapper, Book(author=author1, title="Book 1", data=Dict("key"=>"Some 1")))
    insert!(mapper, Book(author=author1, title="Book 2", data=Dict("key"=>"Some 2")))
    insert!(mapper, Book(author=author1, title="Book 3", data=Dict("key"=>"Some 3")))

    insert!(mapper, Book(author=author3, data=Dict("key"=>"Some 3")))
    delete!(mapper, author3)

    #select_all(mapper, Book, author=author1)



end
function _test_basic_functionalities(creator)
    mapper = DBMapper(creator)

    register!(mapper, Author)
    register!(mapper, Book)
    configure_relation(mapper, Book, :author, on_delete=Cascade())
    @test haskey(mapper.tables, Author)
    @test haskey(mapper.tables, Book)

    create_table(mapper, Author)
    create_table(mapper, Book)

    author = Author(name="pirulo", age=50, country="Argentina")
    insert!(mapper, author)
    @test !isnothing(author.id.x)
    id = author.id.x

    author = Author(name="Author 1", age=3, country="Argentina")
    insert!(mapper, author)

    author = Author(name="Author 2", age=3, country="Brasil")
    insert!(mapper, author)

    author = Author(name="Author 5", age=25, country="Italia")
    insert!(mapper, author)

    author = Author(name="Author 3", age=3, country="Uruguay")
    insert!(mapper, author)

    @test StructDatabaseMapping.exists(mapper, Author, name="Enrique Banch") == false
    @test StructDatabaseMapping.exists(mapper, Author, name="pirulo") == true
    @test StructDatabaseMapping.exists(mapper, author) == true

    @test StructDatabaseMapping.exists(mapper, Author, name="Author 3", age=3) == true
    @test StructDatabaseMapping.exists(mapper, Author, name="Author 3", age=4) == false
    @test StructDatabaseMapping.exists(mapper, Author, pk=author.id.x, age=3) == true
    @test StructDatabaseMapping.exists(mapper, Author, pk=author.id.x, age=4) == false


    authors = select_all(mapper, Author, age=3)
    @test isa(authors[1], Author)
    @test length(authors) == 3

    authors = select_all(mapper, Author)
    @test length(authors) == 5

    authors = select_all(mapper, Author, age=3, fields=[:name, :country])
    @test Set([author.country for author in authors]) == Set(["Brasil", "Argentina", "Uruguay"])


    a = select_one(mapper, Author, id=999)
    @test isnothing(a)
    a = select_one(mapper, Author, id=id)
    @test a.name == "pirulo"

    a.name = "otro_pirulo"
    a.age = 5
    update!(mapper, a; fields=[:name])
    author = select_one(mapper, Author, id=id)
    @test author.name == "otro_pirulo"
    @test author.age == 50

    author.name = "some_other_name"
    author.age = 5
    update!(mapper, author)
    author = select_one(mapper, Author, id=id)
    @test author.name == "some_other_name"
    @test author.age == 5

    book = Book(id="super_string_id", author=author,
                data=Dict{String, Integer}("some_data"=>5))
    insert!(mapper, book)

    a = select_one(mapper, Book, id="bbb")
    @test isnothing(a)
    a = select_one(mapper, Book, id="super_string_id")

    @test a.id.x == "super_string_id"
    @test get(a.author, mapper).name == "some_other_name"
    @test a.data["some_data"] == 5

    book = select_one(mapper, Book, id="super_string_id")
    delete!(mapper, book)

    author = select_one(mapper, Author, id=id)
    @test author.name == "some_other_name"
    @test author.age == 5
    delete!(mapper, Author, name="some_other_name")

    author = select_one(mapper, Author, id=id)
    @test isnothing(author)





end