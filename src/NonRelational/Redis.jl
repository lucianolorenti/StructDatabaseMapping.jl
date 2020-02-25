database_kind(c::Type{Redis.RedisConnection}) = NonRelational

function redis_id(elem::Type{T}, id) where T<:Model
    return "$T:$id"
end

function insert!(mapper::DBMapper, ::Type{Redis.RedisConnection}, elem::T)  where T<:Model
    table = mapper.tables[T]
    conn = get_connection(mapper.pool)
    if table.primary_key.has_auto_value
        setid!(elem, mapper, generate_id(elem, idtype(T, mapper)))
    end
    id = redis_id(T, getid(elem, mapper))
    result = Redis.hmset(conn, id, marshal(mapper, elem))
    release_connection(mapper.pool, conn)    
end

function select_one(mapper::DBMapper, ::Type{Redis.RedisConnection}, T::Type{<:Model}; kwargs...)
    params = Dict(kwargs...)
    id_field = idfield(mapper, T)
    id = params[id_field]
    conn = get_connection(mapper.pool)
    result = Redis.hgetall(conn, redis_id(T, id))
    release_connection(mapper.pool, conn) 
    if isempty(result)
        return nothing
    else
        return T(;unmarshal(mapper, T, result)...)
    end
end

function clean_table!(mapper::DBMapper, ::Type{Redis.RedisConnection}, elem::Type{T})  where T<:Model
    conn = get_connection(mapper.pool)
    keys = Redis.keys(conn, "$T:*")
    result = Redis.del(conn, keys...)
    release_connection(mapper.pool, conn)    
end

function drop_table!(::DBMapper, ::Type{Redis.RedisConnection}, elem::Type{T})  where T<:Model
    
end
function update!(mapper::DBMapper, ::Type{Redis.RedisConnection}, elem::T; fields::Array{Symbol}=Symbol[])  where T<:Model
    id = getid(elem, mapper)
    if id === nothing
        throw("The element does not have id. Cannot update")
    end
    data = marshal(mapper, elem)
    if length(fields) > 0
        for f in keys(data) 
            if !(f in fields)
                pop!(data, f)        
            end
        end
    end
    id = redis_id(T, id)
    conn = get_connection(mapper.pool)    
    result = Redis.hmset(conn, id, data)
    release_connection(mapper.pool, conn)    
end
