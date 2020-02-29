database_kind(c::Type{Redis.RedisConnection}) = NonRelational

redis_id(::Type{T}, id) where T<:Model = "$T:$id"
redis_wildcard(::Type{T}) where T<:Model = "$T:*"

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
    (cursor, results) = Redis.scan(conn, 0, "match", redis_wildcard(T))
    Redis.unlik(conn, keys...)
    while cursor != 0
        (cursor, results) = Redis.scan(conn, cursor, "match", redis_wildcard(T))
        Redis.unlik(conn, keys...)
    end
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

function extract_id_from_kwargs(mapper::DBMapper, T::Type{<:Model}; kwargs...)
    id_f = idfield(mapper, T)
    params = Dict(kwargs...)
    id = nothing
    if haskey(params, id_f)
        id = redis_id(T, pop!(params, id_f))        
    end    
    return (id, params)
end

function exists(mapper::DBMapper, dbtype::Type{Redis.RedisConnection}, T::Type{<:Model}; kwargs...)
    (id, params) = extract_id_from_kwargs(mapper, T; kwargs...)
    # Query with id
    if id !== nothing 
        # Only id
        if length(params) == 0
            conn = get_connection(mapper.pool)                
            result = Redis.exists(conn, id)
            release_connection(mapper.pool, conn)    
            return result
        else 
            # ID & fields
            conn = get_connection(mapper.pool)    
            params_key = collect(keys(params))
            elem_values = Redis.hmget(conn, id, params_key...)
            release_connection(mapper.pool, conn) 
            elem = unmarshal(mapper, T, Dict(zip(params_key, elem_values)); partial=true)
            return all([params[k] == elem[k] for k in params_key])
        end
    else 
        conn = get_connection(mapper.pool)        
        cursor = -1
        params_key = collect(keys(params))
        while cursor != 0
            (cursor, results) = Redis.scan(conn, cursor == -1 ? 0 : cursor, "match", redis_wildcard(T))
            for elem_key in results
                elem_values = Redis.hmget(conn, elem_key, params_key...)
                elem = unmarshal(mapper, T, Dict(zip(params_key, elem_values)); partial=true)
                found = all([params[k] == elem[k] for k in params_key])
                if found
                    release_connection(mapper.pool, conn) 
                    return found
                end
            end 
        end
        release_connection(mapper.pool, conn) 
    end
    return false
end

function Base.delete!(mapper::DBMapper, ::Type{Redis.RedisConnection}, T::Type{<:Model}; kwargs...) 
    (id, params) = extract_id_from_kwargs(mapper, T; kwargs...)
    if id !== nothing
        if length(params) == 0
            conn = get_connection(mapper.pool)                
            result = Redis.del(conn, id)
            release_connection(mapper.pool, conn) 
        else
            conn = get_connection(mapper.pool)    
            params_key = collect(keys(params))
            elem_values = Redis.hmget(conn, id, params_key...)
            release_connection(mapper.pool, conn) 
            elem = unmarshal(mapper, T, Dict(zip(params_key, elem_values)); partial=true)
            if all([params[k] == elem[k] for k in params_key])
                Redis.del(conn, id)
            end
        end
    else
        conn = get_connection(mapper.pool)        
        cursor = -1
        params_key = collect(keys(params))
        while cursor != 0
            (cursor, results) = Redis.scan(conn, cursor == -1 ? 0 : cursor, "match", redis_wildcard(T))
            for elem_key in results
                elem_values = Redis.hmget(conn, elem_key, params_key...)
                elem = unmarshal(mapper, T, Dict(zip(params_key, elem_values)); partial=true)
                if all([params[k] == elem[k] for k in params_key])                                    
                    Redis.del(conn, elem_key)
                end
            end 
            release_connection(mapper.pool, conn) 
        end
    end
end