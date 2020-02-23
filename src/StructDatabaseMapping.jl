module StructDatabaseMapping
export DBMapper, register!, process,  create_table, DBId, 
       Nullable, analyze_relations, ForeignKey, select_one,
       clean_table!, drop_table!, Model, getid
using Dates
using Requires

import Base.insert!

abstract type Connection end
abstract type DatabaseType end

include("Connection/Pool.jl")


abstract type Model end

@enum RELATION_TYPE  ONE_TO_MANY=1 ONE_TO_ONE=2

abstract type AbstractNullable{T} end

mutable struct Nullable{T} <: AbstractNullable{T}
    x::Union{T,Nothing}
end

function Base.convert(::Type{F}, x::J) where F<:AbstractNullable{T}  where J<:T where T
    return F(x)
end

function Base.convert(::Type{F}, x::Nothing) where F<:AbstractNullable{T} where T
    return F(nothing)
end

mutable struct DBId{T} <: AbstractNullable{T}
    x::Union{T,Nothing}
end
function DBId{T}() where T
    return DBId{T}(nothing)
end


element_type(x::DataType) = x
element_type(data::Type{<:AbstractNullable{T}}) where T = T
has_value(data::T) where T<:AbstractNullable = !isnothing(data.x)
set!(data::T, elem::J) where T<:AbstractNullable{J} where J = data.x = elem

mutable struct ForeignKey{T} <: AbstractNullable{T}
    data::Union{T, Nothing}
    loaded::Bool
end
function ForeignKey{T}(;data::Union{T,Nothing}=nothing, loaded::Bool=false) where T<:Model
    return ForeignKey{T}(data, loaded)
end
function ForeignKey{T}(data::Union{T,Nothing}) where T<:Model
    return ForeignKey{T}(data, true)
end

mutable struct Field
    name::Symbol
    struct_field::Symbol
    type::Type
    nullable::Bool
    default::Union{Any, Nothing}
end
function Field(name::Symbol, type::Type)
    primary_key = false
    nullable = false
    db_field_name = name
    if type <: ForeignKey        
        db_field_name = Symbol(string(db_field_name) * "_id")
    elseif type <: AbstractNullable
        nullable = true
    end
    
    return Field(db_field_name, name, type, nullable, primary_key)
end



mutable struct Key
    field::Array{Field}
    has_auto_value::Bool
    is_primary::Bool
end
Key(f::Field; primary::Bool=false, auto_value::Bool=false) = Key([f], auto_value, primary)


struct Relation
    referenced_table::String
    referenced_field::Symbol
    local_field::Symbol 
end

mutable struct Table
    name::String
    data_type
    fields::Array{Field}
    relations::Dict{Field, Relation}
    primary_key::Key
end


isprimarykey(f::Field, t::Table) = t.primary_key.field[1] === f


mutable struct DBMapper
    tables::Dict{DataType, Table}
    pool::ConnectionPool
    dirty::Bool
    function DBMapper(database_builder::Function) 
        return new(Dict{DataType,Table}(), SimplePool(database_builder), false)
    end
end

function idfield(mapper::DBMapper, T::DataType)  :: Symbol
    table = mapper.tables[T]
    return table.primary_key.field[1].name
end
function getid(elem::T, mapper::DBMapper) where T<:Model
    getfield(elem, idfield(mapper, T)).x
end

function setid!(elem::T, mapper::DBMapper, id)  where T<:Model
    id_field = getfield(elem, idfield(mapper, T))
    set!(id_field, id)
end
idfieldtype(::Type{T}, mapper::DBMapper) where T<:Model =  fieldtype(T, idfield(mapper, T))
function idtype(::Type{T}, mapper::DBMapper) where T<:Model
    id_field_type = fieldtype(T, idfield(mapper, T))
    return element_type(id_field_type)
end
function Base.get(v::ForeignKey{T}, mapper::DBMapper) where T
    if v.loaded
        return v.data
    end
    params = Dict{Symbol, Any}(idfield(mapper, T)=>getid(v.data, mapper))
    v.data = select_one(mapper, T;params...)
    v.loaded = true
    return v.data
end
function register!(mapper::DBMapper, d::Type{T}; table_name::String="") where T
    mapper.dirty = true
    if table_name == ""
        table_name = String(split(lowercase(string(T)), ".")[end])
    end
    fields = Field[]
    primary_key = nothing
    for (field_name, field_type) in zip(fieldnames(d), fieldtypes(d))
        db_field = Field(field_name, field_type)
        if field_type <: DBId
            primary_key = Key(db_field; primary=true, auto_value=element_type(db_field.type) <: Integer)
        end
        push!(fields, db_field)
    end

    table = Table(table_name,
                  T,
                  fields,
                  Dict{Field, Relation}(),
                  primary_key)
    mapper.tables[T] =  table
end
function analyze_relations(mapper::DBMapper)
    for table in values(mapper.tables)
        for field in table.fields
            if field.type <: ForeignKey
                referenced_table = mapper.tables[element_type(field.type)]
                referenced_field = referenced_table.primary_key.field[1]
                table.relations[field] = Relation(referenced_table.name,
                                                  referenced_field.name,
                                                  field.name)
            end
        end
    end
    mapper.dirty = false
end
function column_names(mapper, T::DataType) :: Array
    table = mapper.tables[T]
    return map(field->field.name, table.fields)
end
normalize(dbtype, x) = x
normalize(dbtype, x::DBId{T}) where T = x.x
normalize(dbtype, x::ForeignKey{T}) where T = normalize(dbtype, x.data.id)
function struct_field_values(mapper, elem::T; ignore_primary_key::Bool=true) where T
    table = mapper.tables[T]
    column_names = []
    values = []
    for field in table.fields
        if isprimarykey(field, table) && table.primary_key.has_auto_value && ignore_primary_key
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




function check_valid_type(mapper::DBMapper, T::DataType)
    if !haskey(mapper.tables, T)
        throw("Invalid type")
    end
    if mapper.dirty == true 
        analyze_relations(mapper)
    end
end

function create_table(mapper::DBMapper, T::DataType; if_not_exists::Bool=true)
    check_valid_type(mapper, T)
    create_table(mapper, database_kind(mapper.pool.dbtype), T)    
end

function insert!(mapper::DBMapper, elem::T) where T
    check_valid_type(mapper, T)
    insert!(mapper, database_kind(mapper.pool.dbtype), elem)
end

function select_one(mapper::DBMapper, T::DataType; kwargs...) 
    check_valid_type(mapper, T)
    return select_one(mapper, database_kind(mapper.pool.dbtype), T; kwargs...)
end

function clean_table!(mapper::DBMapper, T::DataType)
    check_valid_type(mapper, T)
    clean_table!(mapper, database_kind(mapper.pool.dbtype), T)
end


function drop_table!(mapper::DBMapper, T::DataType)
    check_valid_type(mapper, T)
    drop_table!(mapper, database_kind(mapper.pool.dbtype), T)
end



database_kind(c::Type{T}) where T = throw("Unknow database kind")



function configure_relation(mapper::DBMapper, T::Type, field; on_delete=true)
    table  = mapper.tables[T]
end

function __init__()
  
    @require DBInterface="a10d1c49-ce27-4219-8d33-6db1a4562965" begin       
        include(joinpath(@__DIR__, "Relational", "Relational.jl"))  
    end
    @require SQLite="0aa819cd-b072-5ff4-a722-6bc24af294d9" begin
        include(joinpath(@__DIR__, "Relational", "SQLite.jl"))        
        
    end        
    @require LibPQ="194296ae-ab2e-5f79-8cd4-7183a0a5a0d1" begin 
        include(joinpath(@__DIR__,  "Relational", "PostgreSQL.jl"))
    end
    @require Redis="0cf705f9-a9e2-50d1-a699-2b372a39b750" begin 
        include(joinpath(@__DIR__, "NonRelational", "Redis.jl"))
        include(joinpath(@__DIR__, "NonRelational", "NonRelational.jl"))
    end
    
    
end

end # module
