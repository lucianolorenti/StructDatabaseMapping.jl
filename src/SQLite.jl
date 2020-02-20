

using .SQLite
using .DBInterface

const SQLITE_TYPE_MAPPINGS = Dict{Union{DataType, Symbol}, Symbol}( # Julia => SQLite
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



function database_column_type(dbtype::Type{SQLite.DB}, d::Union{DataType, Symbol}) :: Symbol
    return SQLITE_TYPE_MAPPINGS[d]
end

function clean_table_query(table::Table, dbtype::Type{SQLite.DB}) 
    return "DELETE FROM $(table.name)"
end
database_type(c::Type{SQLite.DB}) = Relational
close!(db::SQLite.DB) = DBInterface.close!(db)