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

function select_by_key_and_params(mapper::DBMapper, dbtype::Type{Redis.RedisConnection}, T::Type{<:Model}, pk, params)
    conn = get_connection(mapper.pool)
    params_key = collect(keys(params))
    elem_values = Redis.hmget(conn, pk, params_key...)
    release_connection(mapper.pool, conn)
    return unmarshal(mapper, T, Dict(zip(params_key, elem_values)); partial=true)
end

function iterate_all(mapper::DBMapper,  dbtype::Type{Redis.RedisConnection}, T::Type{<:Model}, 
                    conditions, apply_function, fields::Array{Symbol}=Symbol[])
    conn = get_connection(mapper.pool)
    cursor = -1
    conditions_fields = collect(keys(conditions))
    if isempty(fields)
        fields = column_names(mapper, T)
    end
    fields_to_obtain = union(conditions_fields, fields)
    while cursor != 0
        (cursor, results) = Redis.scan(conn, cursor == -1 ? 0 : cursor, "match", redis_wildcard(T))
        for elem_key in results            
            elem_values = Redis.hmget(conn, elem_key, fields_to_obtain...)
            elem = unmarshal(mapper, T, Dict{Symbol, Any}(zip(fields_to_obtain, elem_values)); partial=true)
            ret = apply_function(elem_key, elem, conditions, conditions_fields)        
            if (typeof(ret) <: Bool && ret == true) || (!(typeof(ret) <: Bool) && ret !== nothing)
                release_connection(mapper.pool, conn)
                return ret
            end
        end
    end
    release_connection(mapper.pool, conn)
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
            elem = select_by_key_and_params(mapper, dbtype, T, id, params)            
            return all([params[k] == elem[k] for k in keys(params)])
        end
    else
        found = (elem_id, elem, params, params_key)->all([params[k] == elem[k] for k in params_key])
        ret = iterate_all(mapper, dbtype, T, params, found)
        if ret !== nothing 
            return ret
        end
    end
    return false
end
import Base:delete!
function delete!(mapper::DBMapper, dbtype::Type{Redis.RedisConnection}, T::Type{<:Model}; kwargs...)
    (id, params) = extract_id_from_kwargs(mapper, T; kwargs...)
    if id !== nothing
        if length(params) == 0
            conn = get_connection(mapper.pool)
            result = Redis.del(conn, id)
            release_connection(mapper.pool, conn)
        else
            elem = select_by_key_and_params(mapper, dbtype, T, id, params)
            if all([params[k] == elem[k] for k in keys(params)])
                Redis.del(conn, id)
            end
        end
    else
        all_keys_to_delete = []
        add_keys = (elem_key, elem, params, params_key)->begin
            if all([params[k] == elem[k] for k in params_key])
                push!(all_keys_to_delete, elem_key)
            end
            return nothing
        end
        ret = iterate_all(mapper, dbtype, T, params, add_keys)
        conn = get_connection(mapper.pool)
        for elem_key in all_keys_to_delete
            Redis.del(conn, elem_key)
        end
        release_connection(mapper.pool, conn)
    end
end

function select_all(mapper::DBMapper, dbtype::Type{Redis.RedisConnection}, T::Type{<:Model}; fields::Array{Symbol}=[], kwargs...) ::Array{T}
    conditions = Dict(kwargs...)
    all_elems = []
    found_function = (elem_key, elem, params, params_key)->begin
        if all([params[k] == elem[k] for k in params_key])
            push!(all_elems, elem)
        end
        return nothing
    end
    ret = iterate_all(mapper, dbtype, T, conditions, found_function, fields)
    if isempty(all_elems)
        return nothing
    else
        return [T(;unmarshal(mapper, T, elem, partial=!isempty(fields))...) for elem in all_elems]
    end
end
