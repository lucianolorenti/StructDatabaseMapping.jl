
const LIBPQ_TYPE_MAPPINGS = Dict{Union{DataType, Symbol}, Symbol}( # Julia / Postgres
  Char       => :CHARACTER,
  String     => :VARCHAR,
  Integer    => :INTEGER,
  Int        => :INTEGER,
  Float64    => :FLOAT,
  DateTime   => :TIMESTAMP,
  Time       => :TIME,
  Date       => :DATE,
  Bool       => :BOOLEAN,
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

function database_column_type(dbtype::Type{LibPQ.Connection}, d::Union{DataType, Symbol}) :: Symbol
    return LIBPQ_TYPE_MAPPINGS[d]
end

function clean_table_query(table::Table, dbtype::Type{LibPQ.Connection}) 
    return "DELETE FROM $(table.name)"
end
database_type(c::Type{LibPQ.Connection}) = Relational
close!(db::LibPQ.Connection) = DBInterface.close!(db)

DBInterface.close!(db::LibPQ.Connection) = LibPQ.close(db)
DBInterface.execute(db::LibPQ.Connection, sql::AbstractString) = LibPQ.execute(db, sql)

struct LibPQStatement
    sql::AbstractString
    params
end
function DBInterface.prepare(db::LibPQ.Connection, sql::AbstractString) 
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
DBInterface.execute(stmt::LibPQ.Statement, params::Array{Any,1}) = LibPQ.execute(stmt, params)
function DBInterface.lastrowid(r::LibPQ.Result)
    println(LibPQ.result(collect(r)[1]))
    return 5
end