module Jos

# -- Classes --

struct MClass
    name::Symbol
    super::Vector{MClass}
    direct_slots::Vector{Symbol}
end

Top = MClass(:Top, MClass[], Symbol[])

Object = MClass(:Object, MClass[Top], Symbol[])

Method = MClass(:Method, MClass[Top], Symbol[])

MetaObject = MClass(:MetaObject, MClass[Object], Symbol[])

# Meta Objects

Class = MClass(:Class, MClass[MetaObject], Symbol[])

BuiltInClass = MClass(:BuiltInClass, MClass[Class], Symbol[])

GenericFunction = MClass(:GenericFunction, MClass[Method, MetaObject], Symbol[])

# Built-in classes

_Int64 = MClass(:_Int64, MClass[BuiltInClass], Symbol[:value])

_String = MClass(:_String, MClass[BuiltInClass], Symbol[:value])

function class_of(_::MClass)
    Class
end

function Base.show(io::IO, cls::MClass) 
    print(io, "<Class $(cls.name)>")
end

# TODO @defclass(name, super, slots)
# if super is [], then super = [Object]

# -- Instances --

struct Instance
    class::MClass
    slots::Dict{Symbol,Any}
end

function Base.getproperty(obj::Instance, name::Symbol)
    Base.getfield(obj, :slots)[name]
end

function Base.setproperty!(obj::Instance, name::Symbol, value)
    Base.getfield(obj, :slots)[name] = value
end

function class_of(obj::Instance)::MClass
    Base.getfield(obj, :class)
end

function new(class::MClass; arg...)::Instance
    slots = Dict{Symbol,Any}()
    for (k, v) in arg
        if !(k in class.direct_slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end
    Instance(class, slots)
end

# -- Functions and Methods j--

struct MMethod
    name::Symbol
    body::Function
    params::Vector{Tuple{Symbol, MClass}}
end

function Base.show(io::IO, m::MMethod)
    print(io, "<Method $(m.name) $(m.params)>")
end

function class_of(_::MMethod)::MClass
    Method
end

struct MGenericFunction
    name::Symbol
    params::Vector{Symbol}
    methods::Vector{MMethod}
end

function Base.show(io::IO, f::MGenericFunction)
    print(io, "<GenericFunction $(f.name) $(f.params)>")
end

function (f::MGenericFunction)(; arg...)::Any
    if length(f.methods) == 0
        error("No aplicable method for function $(f.name) with arguments $(arg)")
    end
    # TODO: Compute the applicable method(s)
end

function class_of(_::MGenericFunction)::MClass
    GenericFunction
end

end # module Jos
