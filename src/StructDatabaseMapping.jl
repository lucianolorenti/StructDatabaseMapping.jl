module StructDatabaseMapping
export DBMapper, register!, process,
    create_table, DBId, Nullable,
    analyze_relations, ForeignKey
using Dates
import Base.insert!
@enum RELATION_TYPE  ONE_TO_MANY=1 ONE_TO_ONE=2

include("Pool.jl")

abstract type Connection end


abstract type AbstractNullable{T} end

struct Nullable{T} <: AbstractNullable{T}
    x::T
end
struct DBId{T} <: AbstractNullable{T}
    x::Union{T,Nothing}
end
function DBId{T}() where T
    return DBId{T}(nothing)
end

element_type(data::Type{<:AbstractNullable{T}}) where T = T
has_value(data::T) where T<:AbstractNullable = !isnothing(data.x)

struct ForeignKey{T} <: AbstractNullable{T}
    data::Array{T}
end

mutable struct Field
    name::Symbol
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
    return Field(name, type, nullable, primary_key)
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
    DBMapper(database_builder::Function) = new(Dict{DataType,Table}(), SimplePool(database_builder))
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

const TYPE_MAPPINGS = Dict{DataType, Symbol}( # Julia => SQLite
  Char       => :CHARACTER,
  String     => :VARCHAR,
  Integer    => :INTEGER,
  Int        => :INTEGER,
  Float64    => :FLOAT,
  DateTime   => :DATETIME,
  Time       => :TIME,
  Date       => :DATE,
  Bool       => :BOOLEAN
)

function create_table(mapper::DBMapper, T::DataType; if_not_exists::Bool=true)
    table = mapper.tables[T]

    create_table_fields = []
    for field in table.fields
        if field.type <: ForeignKey
            db_field_type  = string(TYPE_MAPPINGS[Integer])
        else
            db_field_type  = string(TYPE_MAPPINGS[field.type])
        end
        primary_key = field.primary_key ? "PRIMARY KEY" : ""
        nullable = field.nullable ? "" : "NOT NULL"
        push!(create_table_fields, strip("$(field.name) $db_field_type $primary_key $nullable"))
    end
    create_table_fields = join(create_table_fields, ", ")
    if_not_exists_str = if_not_exists ? "IF NOT EXISTS" : ""
    sql = strip("""CREATE TABLE $if_not_exists_str $(table.name) ($create_table_fields)""")
    return sql
end


function __init__()
    @require SQlite="c91e804a-d5a3-530f-b6f0-dfbca275c004" begin
        database_type(c::SQLite) = Relational
    end
end
end

struct Relational end
struct NonRelational end

function insert!(mapper::DBMapper, elem::T) where T
    if !haskey(mapper.tables, T)
        throw("a")
    end
    conn = get_connection(mapper.pool)
    insert!(conn, database_type(conn), elem)
    release_connection(mapper.pool, con)
end

function insert!(conn, ::Type{Relational}, elem::T) where T
    table = mapper.tables[T]
    column_names = join(map(x->x.name, table.fields), ",")
    values_placeholder = join(repeat(['?'], length(table.fields)), ",")
    sql = """
INSERT INTO $(table.name) ($column_names)
VALUES ($values_placeholder)
    """
    return sql
end
end # module
