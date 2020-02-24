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
    data::Dict{String, Integer}
end
function Book(;id::Union{String, Nothing}=nothing,
               author::Foreign{Author}=Author(),
               data::Dict{String, Integer}=Dict())
    return Book(id, author, data)
end