
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

create_table_field(field::Field, table::Table, dbtype::DataType) = create_table_field(field, table)
function create_table_field(field::Field, table::Table)
    field_name = "$(field.name)"
    if field.type <: ForeignKey
        db_field_type  = string(TYPE_MAPPINGS[Integer])
    else
        db_field_type  = string(TYPE_MAPPINGS[field.type])
    end
    primary_key = isprimarykey(field, table) ? "PRIMARY KEY" : ""
    nullable = field.nullable ? "" : "NOT NULL"
    return strip("$field_name $db_field_type $primary_key $nullable")
end
function create_table_query(mapper::DBMapper, T::DataType; if_not_exists::Bool=true) :: String
    table = mapper.tables[T]
    create_table_fields = []
    for field in table.fields        
        push!(create_table_fields, create_table_field(field, table, mapper.pool.dbtype))
    end
    create_table_fields = join(create_table_fields, ", ")
    if_not_exists_str = if_not_exists ? "IF NOT EXISTS" : ""
    return String(strip("""CREATE TABLE $if_not_exists_str $(table.name) ($create_table_fields)"""))
end

function create_table(mapper::DBMapper, dbtype::Type{Relational}, T::DataType; if_not_exists::Bool=true)
    sql = create_table_query(mapper, T, if_not_exists=if_not_exists)
    @info sql
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql)
    release_connection(mapper.pool, conn)
    return result
end




insert_query(table::Table, column_names::Array, dbtype) = insert_query(table, column_names)

function insert_query(table::Table, column_names::Array) where T
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
    table = mapper.tables[T]
    sql = insert_query(table, column_names, mapper.pool.dbtype)
    @info sql
    conn = get_connection(mapper.pool)
    stmt = DBInterface.prepare(conn, sql) 
    result = DBInterface.execute(stmt, values)
    id = DBInterface.lastrowid(result)
    release_connection(mapper.pool, conn)
    if table.primary_key.has_auto_value
        set!(elem.id, id)
    end
    return elem
end

db_to_julia(dbtype, dest::DataType, orig)  =  db_to_julia(dest, orig)
db_to_julia(dest::DataType, orig) = orig
db_to_julia(dest::Type{DateTime}, orig::String)  = DateTime(orig)
db_to_julia(dest::Type{ForeignKey{J}}, orig) where J = ForeignKey{J}(orig)

"""
    function totuple(table::Table, dbtype::DataType, db_results) :: Array{Array{Pair}}

Return an array of array of tuples (field=>value). The values are converted to the julia types
"""
function totuple(table::Table, dbtype::DataType, db_results) :: Array{Array{Pair}}
    results = []
    for row in db_results
        r = []
        db_data = Dict(field=>getindex(row, field) 
                      for field in propertynames(row))
        for field in table.fields
            push!(r, field.struct_field=>db_to_julia(dbtype, field.type, db_data[field.name]))
        end             
        push!(results, r)
    end
    return results
end

escape_value(x) = x
escape_value(x::AbstractString) = "\"$x\""

function select_one(mapper::DBMapper, dbtype::Type{Relational}, T::Type; kwargs...) 
    table = mapper.tables[T]
    cnames = join(column_names(mapper, T), ", ")
    conditions = join(["$field=$(escape_value(value))" for (field,value) in kwargs], " ")
    sql = """
    SELECT  $cnames
    FROM $(table.name)
    WHERE $(conditions)
    LIMIT 1
    """
    @info sql
    conn = get_connection(mapper.pool)
    result = totuple(table, mapper.pool.dbtype, DBInterface.execute(conn, sql))
    release_connection(mapper.pool, conn)
    if isempty(result)
        return nothing
    else
        return T(;result[1]...)
    end
end


clean_table_query(table::Table,  dbtype) = clean_table_query(table)

function clean_table_query(table::Table) where T
    return "TRUNCATE TABLE $(table.name)"
end

function clean_table!(mapper::DBMapper, dbtype::Type{Relational}, T::Type)
    table = mapper.tables[T]
    sql = clean_table_query(table, mapper.pool.dbtype)
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql)
    release_connection(mapper.pool, conn)    
end

drop_table_query(table::Table,  dbtype) = drop_table_query(table)

function drop_table_query(table::Table) where T
    return "DROP TABLE $(table.name)"
end

function drop_table!(mapper::DBMapper, dbtype::Type{Relational}, T::Type)
    table = mapper.tables[T]
    sql = drop_table_query(table, mapper.pool.dbtype)
    @info sql
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql)
    release_connection(mapper.pool, conn)    
end