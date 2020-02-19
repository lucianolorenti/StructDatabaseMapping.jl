
struct Relational <: DatabaseType end

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
function create_table_query(mapper::DBMapper, T::DataType; if_not_exists::Bool=true) :: String
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
    return String(strip("""CREATE TABLE $if_not_exists_str $(table.name) ($create_table_fields)"""))
end

function create_table(mapper::DBMapper, dbtype::Type{Relational}, T::DataType; if_not_exists::Bool=true)
    sql = create_table_query(mapper, T, if_not_exists=if_not_exists)
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql)
    release_connection(mapper.pool, conn)
    return result
end

normalize(dbtype, x) = x



function insert_query(mapper::DBMapper, elem::T, column_names::Array) where T
    table = mapper.tables[T]
    values_placeholder = join(repeat(['?'], length(column_names)), ",")
    column_names = join(column_names, ",")    
    sql = """
INSERT INTO $(table.name) ($column_names)
VALUES ($values_placeholder)
    """
    return sql
end



"""
    function insert!(mapper::DBMapper, dbtype::Type{Relational}, elem::T) where T

Insert the element in the database. Update the id of the element
"""
function insert!(mapper::DBMapper, dbtype::Type{Relational}, elem::T) where T
    (column_names, values) = struct_field_values(mapper, elem)
    sql = insert_query(mapper, elem, column_names)
    conn = get_connection(mapper.pool)
    stmt = DBInterface.prepare(conn, sql) 
    result = DBInterface.execute(stmt, values)
    id = DBInterface.lastrowid(result)
    release_connection(mapper.pool, conn)
    set!(elem.id, id)
    return elem
end

db_to_julia(dbtype, dest::DataType, orig) = db_to_julia(orig, dest)
db_to_julia(dbtype, dest::DataType, orig) = orig
db_to_julia(dest::Type{DateTime}, orig::String)  = DateTime(orig)


function totuple(table::Table, dbtype::DataType, db_results)
    results = []
    for row in db_results
        r = []
        for field in propertynames(row)
            value = db_to_julia(dbtype, getindex(row, prop))
            push!(r, field=>value)
        end
        push!(results, r)
    end
    return results
end

function select_one(mapper::DBMapper, dbtype::Type{Relational}, T::Type; kwargs...) 
    table = mapper.tables[T]
    cnames = join(column_names(mapper, T), ", ")
    conditions = join(["$field=$value" for (field,value) in kwargs], " ")
    sql = """
    SELECT  $cnames
    FROM $(table.name)
    WHERE $(conditions)
    LIMIT 1
    """
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql) |> totuple
    release_connection(mapper.pool, conn)
    if isempty(result)
        return nothing
    else

        return T(;result[1]...)
    end
    

end
