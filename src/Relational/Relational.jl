using .DBInterface
struct Relational <: DatabaseKind end
function clean_sql(s::AbstractString) :: String
    return String(replace(strip(s), r" +"=>" "))
end

function unmarshal(mapper::DBMapper, ::Type{Relational}, dest::Type{ForeignKey{T}}, orig) where T <:Model
    id_field_name = idfield(mapper, T)
    params = Dict{Symbol, Any}(id_field_name=>orig)
    return ForeignKey{T}(data=T(;params...), loaded=false)
end


primary_key_type(dbtype::DataType, x) = x

function create_table_field(mapper::DBMapper, field::Field, table::Table, dbtype::DataType) 
    field_name = "$(field.name)"
    if field.type <: ForeignKey
        referenced_table = mapper.tables[element_type(field.type)]
        referenced_field = referenced_table.primary_key.field[1]
        db_field_type = string(database_column_type(dbtype, element_type(referenced_field.type)))
    elseif field.type <: DBId 
        pk_type = primary_key_type(dbtype, element_type(field.type))
        db_type = database_column_type(dbtype, pk_type)
        db_field_type = string(db_type)
    else
        db_field_type  = string(database_column_type(dbtype, element_type(field.type)))
    end
    primary_key = isprimarykey(field, table) ? "PRIMARY KEY" : ""
    nullable = field.nullable ? "" : "NOT NULL"
    return strip("$field_name $db_field_type $primary_key $nullable")
end


function create_table_query(mapper::DBMapper, T::Type{<:Model}; if_not_exists::Bool=true) :: String
    if mapper.dirty == true 
        analyze_relations(mapper)
    end
    table = mapper.tables[T]
    create_table_fields = []
    for field in table.fields        
        push!(create_table_fields, 
              create_table_field(mapper, field, table, mapper.pool.dbtype))
    end
    
    foreign_keys = ["FOREIGN KEY($(r.local_field)) REFERENCES $(r.referenced_table)($(r.referenced_field))" 
                    for r in values(table.relations)]
    append!(create_table_fields, foreign_keys)
    
    create_table_fields = join(create_table_fields, ", ")
    if_not_exists_str = if_not_exists ? "IF NOT EXISTS" : ""
    return clean_sql("""CREATE TABLE $if_not_exists_str $(table.name) ($create_table_fields)""")
end

function create_table(mapper::DBMapper, dbtype::Type{Relational}, T::Type{<:Model}; if_not_exists::Bool=true)
    sql = create_table_query(mapper, T, if_not_exists=if_not_exists)
    @info sql
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql)
    release_connection(mapper.pool, conn)
    return result
end




insert_query(table::Table, column_names::Array, dbtype) = insert_query(table, column_names)

function insert_query(table::Table, column_names::Array)
    values_placeholder = join(repeat(['?'], length(column_names)), ",")
    column_names = join(column_names, ",")    
    sql = """
INSERT INTO $(table.name) ($column_names)
VALUES ($values_placeholder)
    """
    return clean_sql(sql)
end



"""
    function insert!(mapper::DBMapper, dbtype::Type{Relational}, elem::T) where T

Insert the element in the database. Update the id of the element
"""
function insert!(mapper::DBMapper, dbtype::Type{Relational}, elem::T) where T<:Model
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
        setid!(elem, mapper, id)
    end
    return elem
end



update_query(table::Table, column_names::Array, dbtype) = update_query(table, column_names)

function update_query(table::Table, column_names::Array)    
    column_names = join(map(cname->"$cname=?", column_names), ",")    
    sql = """
    UPDATE $(table.name)
    SET $column_names
    WHERE 
    $(idfield(table)) = ?
    """
    return clean_sql(sql)
end


"""
    function insert!(mapper::DBMapper, dbtype::Type{Relational}, elem::T) where T

Insert the element in the database. Update the id of the element
"""
function update!(mapper::DBMapper, dbtype::Type{Relational}, elem::T; fields::Array{Symbol}=Symbol[]) where T<:Model
    id = getid(elem, mapper)
    if id === nothing
        throw("Id not present, cannot update")
    end
    (column_names, values) = struct_field_values(mapper, elem; ignore_primary_key=true, fields=fields)
    table = mapper.tables[T]
    sql = update_query(table, column_names, mapper.pool.dbtype)
    push!(values, id)
    @info sql
    conn = get_connection(mapper.pool)
    stmt = DBInterface.prepare(conn, sql) 
    result = DBInterface.execute(stmt, values)
    release_connection(mapper.pool, conn)
    return elem
end


"""
    function totuple(mapper::DBMapper, table::Table, dbtype::DataType, db_results) :: Array{Array{Pair}}

Return an array of array of tuples (field=>value). The values are converted to the julia types
"""
function totuple(mapper::DBMapper, table::Table, dbtype::DataType, db_results) :: Array{Array{Pair}}
    results = []
    for row in db_results
        r = []
        db_data = Dict(field=>getindex(row, field) 
                      for field in propertynames(row))
        for field in table.fields
            push!(r, field.struct_field=>unmarshal(mapper, dbtype, field.type, db_data[field.name]))
        end             
        push!(results, r)
    end
    return results
end

function totuple(results) 
    [(;(prop=>getindex(row, prop) for prop in propertynames(row))...) for row in results]
end

function select_one(mapper::DBMapper, ::Type{Relational}, T::Type{<:Model}; kwargs...) 
    dbtype = mapper.pool.dbtype
    table = mapper.tables[T]
    cnames = join(column_names(mapper, T), ", ")
    conditions = join(["$field=?" for (field, value) in kwargs], " AND ")
    values = [v[2] for v in kwargs]
    sql = clean_sql("""
    SELECT $cnames
    FROM $(table.name)
    WHERE $(conditions)
    LIMIT 1
    """)
    @info sql
    conn = get_connection(mapper.pool)
    stmt = DBInterface.prepare(conn, sql)
    result = totuple(mapper, table, dbtype, DBInterface.execute(stmt, values))
    release_connection(mapper.pool, conn)
    if isempty(result)
        return nothing
    else
        return T(;result[1]...)
    end
end


clean_table_query(table::Table,  dbtype) = clean_table_query(table)

function clean_table_query(table::Table)
    return clean_sql("TRUNCATE TABLE $(table.name)")
end

function clean_table!(mapper::DBMapper, dbtype::Type{Relational}, T::Type{<:Model})
    table = mapper.tables[T]
    sql = clean_table_query(table, mapper.pool.dbtype)
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql)
    release_connection(mapper.pool, conn)    
end

drop_table_query(table::Table,  dbtype) = drop_table_query(table)

function drop_table_query(table::Table)
    return clean_sql("DROP TABLE $(table.name)")
end

function drop_table!(mapper::DBMapper, dbtype::Type{Relational}, T::Type{<:Model})
    table = mapper.tables[T]
    sql = drop_table_query(table, mapper.pool.dbtype)
    @info sql
    conn = get_connection(mapper.pool)
    result = DBInterface.execute(conn, sql)
    release_connection(mapper.pool, conn)    
end

function exists(mapper::DBMapper, dbtype::Type{Relational}, T::Type{<:Model}; kwargs...) :: Bool
    table = mapper.tables[T]
    conditions = join(["$field = ?" for (field, value) in kwargs], " AND ")
    values = [v[2] for v in kwargs]
    sql = """
    SELECT COUNT(1) as count
    FROM $(table.name)
    WHERE $conditions
    """
    @info sql
    conn = get_connection(mapper.pool)
    stmt = DBInterface.prepare(conn, sql)
    result = DBInterface.execute(stmt, [value for (f, value) in kwargs])
    release_connection(mapper.pool, conn)  
    result = result |> totuple
    return result[1][:count]
end
