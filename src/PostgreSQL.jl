function clean_table_query(table::Table, dbtype::Type{LibPQ.Connection}) 
    return "DELETE FROM $(table.name)"
end
database_type(c::Type{LibPQ.Connection}) = Relational
close!(db::LibPQ.Connection) = DBInterface.close!(db)