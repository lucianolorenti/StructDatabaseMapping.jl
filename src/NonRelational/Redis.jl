database_kind(c::Type{Redis.RedisConnection}) = NonRelational

function insert!(mapper::DBMapper, ::Type{Redis.RedisConnection}, elem) 
    conn = get_connection(mapper.pool)
    setid!(elem, mapper, generate_id(elem, idtype(elem, mapper)))
    result = Redis.hmset(conn, getid(elem, mapper), marshal(mapper, elem))
    release_connection(mapper.pool, conn)    
end

function select_one(mapper::DBMapper, ::Type{Redis.RedisConnection}, T::DataType; kwargs...)
    params = Dict(kwargs...)
    id_field = idfield(mapper, T)
    id = params[id_field]
    conn = get_connection(mapper.pool)
    result = Redis.hgetall(conn, id)
    release_connection(mapper.pool, conn) 
    if isempty(result)
        return nothing
    else
        return T(;unmarshal(mapper, T, result)...)
    end
end
