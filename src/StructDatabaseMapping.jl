module StructDatabaseMapping
export DBMapper, register!, process,  create_table, DBId, 
       Nullable, analyze_relations, ForeignKey, select_one
using Dates
using Requires

import Base.insert!

abstract type Connection end
abstract type DatabaseType end

include("Pool.jl")




@enum RELATION_TYPE  ONE_TO_MANY=1 ONE_TO_ONE=2

abstract type AbstractNullable{T} end

mutable struct Nullable{T} <: AbstractNullable{T}
    x::T
end
mutable struct DBId{T} <: AbstractNullable{T}
    x::Union{T,Nothing}
end
function DBId{T}() where T
    return DBId{T}(nothing)
end

function Base.convert(::Type{DBId{T}}, x::J) where J<:T where T
    return DBId{T}(x)
end

function Base.convert(::Type{DBId{T}}, x::Nothing) where T
    return DBId{T}(nothing)
end

element_type(data::Type{<:AbstractNullable{T}}) where T = T
has_value(data::T) where T<:AbstractNullable = !isnothing(data.x)
set!(data::T, elem::J) where T<:AbstractNullable{J} where J = data.x = elem
struct ForeignKey{T} <: AbstractNullable{T}
    data::Array{T}
end

mutable struct Field
    name::Symbol
    struct_field::Symbol
    type::Type
    nullable::Bool
    primary_key::Bool
end
function Field(name::Symbol, type::Type)
    primary_key = false
    nullable = false
    if type <: DBId
        primary_key = true
        nullable = true
        type = element_type(type)
    elseif type <: Nullable
        type = element_type(type)
        nullable = true
    end
    return Field(name, name, type, nullable, primary_key)
end


mutable struct Table
    name::String
    data_type
    fields::Array{Field}
    relations::Dict{DataType, Any}
end



function Table(table_name::String, data_type, fields::Array)
    Table(table_name, data_type, fields, Dict{DataType, Any}())
end


mutable struct DBMapper
    tables::Dict{DataType, Table}
    pool::ConnectionPool
    function DBMapper(database_builder::Function) 
        return new(Dict{DataType,Table}(), SimplePool(database_builder))
    end
end

function register!(mapper::DBMapper, d::Type{T}; table_name::String="") where T
    if table_name == ""
        table_name = String(split(lowercase(string(T)), ".")[end])
    end
    fields = Field[]
    for (field_name, field_type) in zip(fieldnames(d), fieldtypes(d))
        push!(fields, Field(field_name, field_type))
    end

    table = Table(table_name,
                  T,
                  fields)
    mapper.tables[T] =  table
end
function analyze_relations(mapper::DBMapper)
    for table in values(mapper.tables)
        for field in table.fields
            field_type = field.type
            if field_type <: Array
                field_type = eltype(field_type)
            end
            if haskey(mapper.tables, field_type) && !haskey(table.relations, field_type)
                r = Relation(ONE_TO_MANY, table, mapper.tables[field_type])
                table.relations[field_type] = r
                mapper.tables[field_type].relations[table.data_type] = r
            end
        end
    end

end


function column_names(mapper, T::DataType) :: Array
    table = mapper.tables[T]
    return map(field->field.name, table.fields)
end

function struct_field_values(mapper, elem::T; ignore_primary_key::Bool=true) where T
    table = mapper.tables[T]
    column_names = []
    values = []
    for field in table.fields
        if (field.primary_key) && ignore_primary_key
            continue
        end
        field_value = getfield(elem, field.struct_field)
        if (field.nullable == true) && !has_value(field_value) 
            continue
        end
        push!(column_names, field.name)
        push!(values, normalize(mapper.pool.dbtype, getfield(elem, field.struct_field)))
    end
    return (column_names, values)
end



struct NonRelational <: DatabaseType end

function check_valid_type(mapper::DBMapper, T::DataType)
    if !haskey(mapper.tables, T)
        throw("Invalid type")
    end
end

function create_table(mapper::DBMapper, T::DataType; if_not_exists::Bool=true)
    check_valid_type(mapper, T)
    create_table(mapper, database_type(mapper.pool.dbtype), T)    
end

function insert!(mapper::DBMapper, elem::T) where T
    check_valid_type(mapper, T)
    insert!(mapper, database_type(mapper.pool.dbtype), elem)
end

function select_one(mapper::DBMapper, T::DataType; kwargs...) 
    check_valid_type(mapper, T)
    select_one(mapper, database_type(mapper.pool.dbtype), T; kwargs...)
end


database_type(c::Type{T}) where T = throw("Unknow database type")

function __init__()
    @require DBInterface="a10d1c49-ce27-4219-8d33-6db1a4562965" begin
        @require SQLite="0aa819cd-b072-5ff4-a722-6bc24af294d9" begin
            fn = joinpath(@__DIR__,  "Relational.jl")
            include(fn)
            database_type(c::Type{SQLite.DB}) = Relational
            close!(db::SQLite.DB) = DBInterface.close!(db)
            
        end        
    end
    
end

end # module
