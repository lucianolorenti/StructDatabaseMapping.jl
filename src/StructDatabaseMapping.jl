module StructDatabaseMapping
export DBMapper, register!, create_table, DBId, 
       Nullable, analyze_relations, ForeignKey, select_one,
       clean_table!, drop_table!, Model, getid, Foreign,
       update!

using Dates
using Requires
using JSON

import Base.insert!

abstract type Connection end
abstract type DatabaseKind end
abstract type Model end


include("Connection/Pool.jl")


"""
    mutable struct Field

Internal field representation
"""
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
function idfield(t::Table)  :: Symbol
    return t.primary_key.field[1].name
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


@enum RELATION_TYPE  ONE_TO_MANY=1 ONE_TO_ONE=2

abstract type AbstractNullable{T} end
"""
    has_value(data::T) where T<:AbstractNullable
"""
has_value(data::T) where T<:AbstractNullable = !isnothing(data.x)

"""
    set!(data::T, elem::J) where T<:AbstractNullable{J}
"""
set!(data::T, elem::J) where T<:AbstractNullable{J} where J = data.x = elem


"""
    mutable struct Nullable{T} <: AbstractNullable{T}

Optional field
"""
mutable struct Nullable{T} <: AbstractNullable{T}
    x::Union{T,Nothing}
end

function Base.convert(::Type{F}, x::T) where F<:AbstractNullable{T}  where T
    return F(x)
end

function Base.convert(::Type{F}, x::Nothing) where F<:AbstractNullable{T}  where T
    return F(nothing)
end

"""
    mutable struct Nullable{T} <: AbstractNullable{T}

Model identifier
"""
mutable struct DBId{T} <: AbstractNullable{T}
    x::Union{T,Nothing}
end
function DBId{T}() where T
    return DBId{T}(nothing)
end

"""
    idfield(mapper::DBMapper, T::DataType)  :: Symbol

Return the identifier field name for the given type
"""
idfield(mapper::DBMapper, T::DataType)  :: Symbol =  idfield(mapper.tables[T])
"""
    function getid(elem::T, mapper::DBMapper) where T<:Model

Return the identifier value for the given type
"""
function getid(elem::T, mapper::DBMapper) where T<:Model
    getfield(elem, idfield(mapper, T)).x
end

"""
    function setid!(elem::T, mapper::DBMapper, id)  where T<:Model

Set the identifier value for the given type
"""
function setid!(elem::T, mapper::DBMapper, id)  where T<:Model
    id_field = getfield(elem, idfield(mapper, T))
    set!(id_field, id)
end
"""
    idfieldtype(::Type{T}, mapper::DBMapper) where T<:Model

Obtain the general id field type for a given type 
for a field with type DBId{Integer} should return DBId{Integer}
"""
idfieldtype(::Type{T}, mapper::DBMapper) where T<:Model =  fieldtype(T, idfield(mapper, T))

"""
    function idtype(::Type{T}, mapper::DBMapper) where T<:Model

Obtain the element type of the identifier field for a given type 
For a field with type DBId{Integer} should return Integer
"""
function idtype(::Type{T}, mapper::DBMapper) where T<:Model
    id_field_type = fieldtype(T, idfield(mapper, T))
    return element_type(id_field_type)
end


"""
    mutable struct Nullable{T} <: AbstractNullable{T}

Foreign Key model field

The foreign key field can be constructed with the T element
or with nothing. The `loaded` field is used in the lazy loading of the foreign
element. When the foreign element is loaded the `loaded` attributed is set 
to true

```
struct ModelA <: Model ... end
struct ModelB <: Model
    ...
    foreign_field::ForeignKey{ModelA}
end
```
"""
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
const Foreign{T} = Union{T, ForeignKey{T}} 

function Base.get(v::ForeignKey{T}, mapper::DBMapper) where T
    if v.loaded
        return v.data
    end
    params = Dict{Symbol, Any}(idfield(mapper, T)=>getid(v.data, mapper))
    v.data = select_one(mapper, T;params...)
    v.loaded = true
    return v.data
end





"""
    function register!(mapper::DBMapper, d::Type{T}; table_name::String="") where T <: Model

Register an element of type T into the mapper.
A Table type is created for the given Model and is stored in the dabase. This function must be called 
for each type you want to use with this library.
"""
function register!(mapper::DBMapper, d::Type{T}; table_name::String="") where T <: Model
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

"""
    function analyze_relations(mapper::DBMapper)

Updates the relations dict of each table.

After calling this function the mapper state is not dirty. 
"""
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

"""
    function column_names(mapper::DBMapper, T::DataType) :: Array

Return the table field names for a given struct. 
"""
function column_names(mapper::DBMapper, T::DataType) :: Array
    table = mapper.tables[T]
    return map(field->field.name, table.fields)
end

"""
    function struct_fields(mapper::DBMapper, T::DataType) :: Array{Symbol}

Return the field names for a given struct. 
Perhaps should be replaced directly with fieldnames
"""
function struct_fields(mapper::DBMapper, T::DataType) :: Array{Symbol}
    table = mapper.tables[T]
    return map(field->field.struct_field, table.fields)
end


normalize(dbtype, x) = x
normalize(dbtype, x::DBId{T}) where T = x.x
normalize(dbtype, x::ForeignKey{T}) where T = normalize(dbtype, x.data.id)
normalize(dbtype, x::AbstractDict) where T = JSON.json(x)
function struct_field_values(mapper, elem::T; ignore_primary_key::Bool=true, fields::Array{Symbol}=Symbol[]) where T
    table = mapper.tables[T]
    column_names = []
    values = []
    for field in table.fields
        if length(fields) > 0 && !(field.struct_field in fields)
            continue
        end
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


"""
    function create_table(mapper::DBMapper, T::Type{<:Model}; if_not_exists::Bool=true)

Create the table for the given model
"""
function create_table(mapper::DBMapper, T::Type{<:Model}; if_not_exists::Bool=true)
    check_valid_type(mapper, T)
    create_table(mapper, mapper.pool.dbtype, T; if_not_exists=if_not_exists)    
end
function create_table(mapper::DBMapper, dbtype::DataType, T::Type{<:Model}; if_not_exists::Bool=true) 
    create_table(mapper, database_kind(dbtype), T; if_not_exists=if_not_exists)
end

function insert!(mapper::DBMapper, elem::T) where T <: Model
    check_valid_type(mapper, T)
    insert!(mapper, mapper.pool.dbtype, elem)
end
function insert!(mapper::DBMapper, dbtype::DataType, elem::T) where T <: Model
    insert!(mapper, database_kind(dbtype), elem)
end

function update!(mapper::DBMapper, elem::T; fields::Array{Symbol}=Symbol[]) where T<:Model
    check_valid_type(mapper, T)
    update!(mapper, mapper.pool.dbtype, elem; fields=fields)
end
function update!(mapper::DBMapper, dbtype::DataType, elem::T; fields::Array{Symbol}=Symbol[]) where T <:Model
    update!(mapper, database_kind(dbtype), elem; fields=fields)
end

"""
    function select_one(mapper::DBMapper, T::Type{<:Model}; kwargs...) 

Select one element of type 
"""
function select_one(mapper::DBMapper, T::Type{<:Model}; kwargs...) 
    check_valid_type(mapper, T)
    return select_one(mapper, mapper.pool.dbtype, T; kwargs...)
end
function select_one(mapper::DBMapper, dbtype::DataType, T::Type{<:Model}; kwargs...) 
    return select_one(mapper, database_kind(dbtype), T; kwargs...)
end

"""
    clean_table!(mapper::DBMapper, T::Type{<:Model})

Remove all elements of the type T but keep, in cases when possible the structure
where those elements are stored (tables in relational case)
"""
function clean_table!(mapper::DBMapper, T::Type{<:Model})
    check_valid_type(mapper, T)
    clean_table!(mapper, mapper.pool.dbtype, T)
end
function clean_table!(mapper::DBMapper, dbtype::DataType, T::Type{<:Model})
    clean_table!(mapper, database_kind(dbtype), T)
end

"""
    function drop_table!(mapper::DBMapper, T::DataType)

Eliminates the Struct data from the DB
"""
function drop_table!(mapper::DBMapper, T::DataType)
    check_valid_type(mapper, T)
    drop_table!(mapper, mapper.pool.dbtype, T)
end
function drop_table!(mapper::DBMapper, dbtype::DataType, T::Type{<:Model})
    drop_table!(mapper, database_kind(dbtype), T)
end

"""
    database_kind(c::Type{T})

Return the kind of the database: Relational or NonRelational

The parameter should be the type of the connection of the concrete
database being used.
Every concrete database implementation must override this function.
"""
database_kind(c::Type{T}) where T = throw("Unknow database kind")



function configure_relation(mapper::DBMapper, T::Type, field; on_delete=true)
    table  = mapper.tables[T]
end

"""
    element_type(x::Type{T}) where T

Return the element type of generic elements or the type itself for a regular type
Also it convert complex types to common one, ex: <:AbstractDict to Dict
"""
element_type(x::Type{T}) where T = x
element_type(x::DataType) = x
element_type(data::Type{<:AbstractNullable{T}}) where T = T
element_type(x::Type{<:AbstractDict}) = Dict

""" 
    unmarshal(mapper::DBMapper, dbtype::DataType, dest::Type, orig)

Convert data obtained form the database to the julia representation.
It has three level of dispatch, the database specific, the database kind specific and 
the type specific.
Return the orig element converted to the dest type. The dest type is usually obtained 
from the struct fields.
"""
unmarshal(mapper::DBMapper, dbtype::DataType, dest::Type, orig) = unmarshal(mapper, database_kind(dbtype), dest, orig)
unmarshal(mapper::DBMapper, dbkind::Type{T}, dest::Type, orig) where T<:DatabaseKind =  unmarshal(mapper, dest, orig)
unmarshal(mapper::DBMapper, dest::Type, orig) = unmarshal(dest, orig)
unmarshal(dest::DataType, orig) = orig
unmarshal(dest::Type{DateTime}, orig::String)  = DateTime(orig)
unmarshal(D::Type{<:Dict}, d::String) = JSON.parse(d, dicttype=D)
unmarshal(mapper::DBMapper, x) = unmarshal(x)
unmarshal(mapper::DBMapper, ttype::Type{T}, x::String) where T = unmarshal(T, x)
unmarshal(x) = x
unmarshal(d::Type{T}, b::String) where T<:Number = parse(T, b)
unmarshal(d::Type{Integer}, b::String) = parse(Int64, b)
unmarshal(d::Type{String}, b::String) = b
unmarshal(::Type{DBId{T}}, x::String) where T<:Integer = parse(UInt64, x)
unmarshal(::Type{DBId{T}}, x::String) where T<:AbstractString = x





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
