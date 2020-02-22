
function generate_id(d, ::Type{Integer}) :: UInt64
    fields = vcat(string(typeof(d)),
                 [string(f, "_", getfield(d, f))
                  for f in fieldnames(typeof(d))])
    return hash(join(fields, "_"))
end

function generate_id(d, ::Type{String}) :: String
    return string(generate_id(d, Integer))
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


unmarshal(mapper::DBMapper, x) = unmarshal(x)
unmarshal(mapper::DBMapper, ttype::Type{T}, x::String) where T = unmarshal(T, x)
"""
If i don't know the type and is not a dict, I return the object itself
"""
unmarshal(x) = x
unmarshal(d::Type{T}, b::String) where T<:Number = parse(T, b)
unmarshal(d::Type{Integer}, b::String) = parse(Int64, b)
unmarshal(d::Type{Dict{K,V}}, b::String) where K where V = JSON.read(b)
unmarshal(d::Type{String}, b::String) = b
unmarshal(::Type{Dates.DateTime}, x::String) = DateTime(x)
unmarshal(::Type{DBId{T}}, x::String) where T = parse(UInt64, x)
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
            val = unmarshal(mapper, DTNext, d[string(iter)])
        end
        out[iter] = val        
    end
    return out
end


symboldict(d::Dict{AbstractString, T}) where T  = Dict{Symbol, Any}(Symbol(k)=>v for (k,v) in d)
symboldict(d::Dict{Symbol, T}) where T = d