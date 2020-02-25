struct NonRelational <: DatabaseKind end




function generate_id(d, ::Type{Integer}) :: UInt64
    fields = vcat(string(typeof(d)),
                 [string(f, "_", getfield(d, f))
                  for f in fieldnames(typeof(d))])
    return hash(join(fields, "_"))
end

function generate_id(d, ::Type{String}) :: String
    return string(generate_id(d, Integer))
end
function create_table(mapper::DBMapper, dbtype::Type{NonRelational}, T::Type{<:Model}; if_not_exists::Bool=true)
end
marshal(mapper::DBMapper, x)  = marshal(x)
marshal(x::AbstractDict{K, V}) where K where V = JSON.json(x)
marshal(x::Array{T}) where T = JSON.json(x)
marshal(x::AbstractString) = x
marshal(d::Enum) = Integer(d)
marshal(d::DateTime) = string(d)
#marshal(d) = d
marshal(d::Number) = d
marshal(d::DBId{T}) where T = marshal(d.x)
marshal(mapper::DBMapper, d::ForeignKey{T}) where T  = getid(d.data, mapper)
    
function unmarshal(mapper::DBMapper, ::Type{NonRelational}, ::Type{ForeignKey{T}}, x::String) where T<:Model
    id_field_name = idfield(mapper, T)
    params = Dict{Symbol, Any}(id_field_name=>unmarshal(mapper, idfieldtype(T, mapper), x))
    return ForeignKey{T}(data=T(;params...), loaded=false)
end

function marshal(mapper::DBMapper, elemid::String, comps::Array)
    for (i, component) in enumerate(comps)
        elem_i_id = "$elemid:$i"
        insert!(mapper, elem_i_id, marshal(mapper, elem_i_id, component))
    end
    return Dict("type"=>"array",
               "length"=>length(comps))
end

function marshal(mapper::DBMapper, x::T) where T<:Model
    d =  Dict()
    for iter in fieldnames(typeof(x))        
        d[iter] = marshal(mapper, marshal(mapper, getfield(x, iter)))
    end
    d[:type] = string(typeof(x))
    return d
end






function unmarshal(mapper::DBMapper, DT::Type, d::AbstractDict)
    out = Dict{Symbol, Any}()
    for iter in fieldnames(DT)
        DTNext = fieldtype(DT, iter)
        if !haskey(d, string(iter))
            # check whether DTNext is compatible with any scheme for missing values
            val = if DTNext <: Nullable
                DTNext()
            elseif Missing <: DTNext
                missing
            elseif Nothing <: DTNext
                Nothing()
            else
                throw(ArgumentError("Key $(string(iter)) is missing from the structure $DT, and field is neither Nullable nor Missings nor Nothing-compatible"))
            end
        else
            val = unmarshal(mapper, mapper.pool.dbtype, DTNext, d[string(iter)])
        end
        out[iter] = val        
    end
    return out
end


symboldict(d::Dict{AbstractString, T}) where T  = Dict{Symbol, Any}(Symbol(k)=>v for (k,v) in d)
symboldict(d::Dict{Symbol, T}) where T = d