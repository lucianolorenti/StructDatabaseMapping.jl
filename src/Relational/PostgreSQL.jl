module PostgreSQLConnection

import StructDatabaseMapping: Relational, Table, database_column_type, clean_table_query,
                              database_kind, close!, close!, primary_key_type, set!,
                              insert_query

using Dates
using StructDatabaseMapping.LibPQ
import DBInterface: prepare, execute, lastrowid, close!, execute


const LIBPQ_TYPE_MAPPINGS = Dict{Union{Type, Symbol}, Symbol}( # Julia / Postgres
  Char => :CHARACTER,
  String => :VARCHAR,
  Integer => :INTEGER,
  Int => :INTEGER,
  Float64 => :FLOAT,
  DateTime => :TIMESTAMP,
  Time => :TIME,
  Date => :DATE,
  Bool => :BOOLEAN,
  Dict => :JSON,

  :Serial => :SERIAL
)
primary_key_type(dbtype::Type{LibPQ.Connection}, x::Type{T}) where T<:Integer = :Serial

function insert_query(table::Table, column_names::Array, dbtype::Type{LibPQ.Connection}) 
    values_placeholder = join(repeat(['?'], length(column_names)), ",")
    column_names = join(column_names, ",")    
    sql = """
INSERT INTO $(table.name) ($column_names)
VALUES ($values_placeholder)
RETURNING id
    """
    return sql
end

function database_column_type(dbtype::Type{LibPQ.Connection}, d::Union{Type, Symbol}) :: Symbol
    return LIBPQ_TYPE_MAPPINGS[d]
end

function clean_table_query(table::Table, dbtype::Type{LibPQ.Connection}) 
    return "DELETE FROM $(table.name)"
end
database_kind(c::Type{LibPQ.Connection}) = Relational
close!(db::LibPQ.Connection) = DBInterface.close!(db)
escape_value(dbtype::Type{LibPQ.Connection}, x::AbstractString) = "'$x'"


close!(db::LibPQ.Connection) = LibPQ.close(db)
execute(db::LibPQ.Connection, sql::AbstractString) = LibPQ.execute(db, sql)

struct LibPQStatement
    sql::AbstractString
    params
end
function prepare(db::LibPQ.Connection, sql::AbstractString) 
    value_holders = [position[1] for position in findall("?", sql)]
    i = 1
    s = ""
    num_params = 0
    for pos in value_holders
        s *= sql[i:pos-1]
        i = pos+1
        num_params += 1
        s *= "\$$num_params"
    end        
    s *= sql[i:end]
    return LibPQ.prepare(db, s)
end
execute(stmt::LibPQ.Statement, params::Array) = LibPQ.execute(stmt, params)
lastrowid(r::LibPQ.Result) =  r[1,1]
Base.getindex(row::LibPQ.Row, symbol::Symbol) = getproperty(row, symbol)
end