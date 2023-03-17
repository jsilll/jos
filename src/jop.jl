module Jop

# -- Classes --

struct MClass
    name::Symbol
    slots::Vector{Symbol}
    super::Vector{MClass}
end

Object = MClass(:Object, Symbol[], MClass[])

Class = MClass(:Class, Symbol[], MClass[Object])

Base.show(io::IO, cls::MClass) = print(io, cls.name)

function class_of(_::MClass)
    Class
end

# -- Instances --

struct Instance
    class::MClass
    slots::Dict{Symbol,Any}
end

function class_of(obj::Instance)::MClass
    obj.class
end

function new(class::MClass; arg...)::Instance
    slots = Dict{Symbol,Any}()
    for (k, v) in arg
        if !(k in class.slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end
    Instance(class, slots)
end

function Base.getproperty(obj::Instance, name::Symbol)
    if name == :class
        Base.getfield(obj, :class)
    else
        Base.getfield(obj, :slots)[name]
    end
end

end # module Jop
