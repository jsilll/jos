module Jos

# ---- Classes ----

struct MClass
    name::Symbol
    direct_slots::Vector{Symbol}
    direct_superclasses::Vector{MClass}
end

Top = MClass(:Top, Symbol[], MClass[]) 

Object = MClass(:Object, Symbol[], MClass[Top]) 

Class = MClass(:Class, Symbol[], MClass[Object]) 

MultiMethod = MClass(:MultiMethod, Symbol[], MClass[Class, Object])

GenericFunction = MClass(:GenericFunction, Symbol[], MClass[Class, Object])


BuiltInClass = MClass(:BuiltInClass, Symbol[], MClass[Class])

_Int64 = MClass(:_Int64, Symbol[:value], MClass[BuiltInClass])

_String = MClass(:_String, Symbol[:value], MClass[BuiltInClass])


function class_of(_::MClass)
    Class
end

function Base.show(io::IO, cls::MClass) 
    print(io, "<Class $(cls.name)>")
end

function Base.getproperty(cls::MClass, name::Symbol)
    if cls === Class && name === :slots
        return [:name, :direct_slots, :direct_superclasses]
    else if cls === MultiMethod && name === :slots
        return [:name, :body, :params]
    else if cls === GenericFunction && name === :slots
        return [:name, :params, :methods]
    else 
        return Base.getfield(cls, name)
    end
end

# TODO:
# @defclass(name, super, slots)
# note: if super is [], then super = [Object]

# ---- Instances ----

struct Instance
    class::MClass
    slots::Dict{Symbol,Any}
end

function class_of(obj::Instance)::MClass
    Base.getfield(obj, :class)
end

function new(class::MClass; args...)::Instance
    if length(args) != length(class.direct_slots)
        error("Invalid number of slots")
    end

    slots = Dict{Symbol,Any}()
    # TODO: handle inherited slots
    for (k, v) in args
        if !(k in class.direct_slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end
    Instance(class, slots)
end

function Base.getproperty(obj::Instance, name::Symbol)
    Base.getfield(obj, :slots)[name]
end

function Base.setproperty!(obj::Instance, name::Symbol, value)
    Base.getfield(obj, :slots)[name] = value
end

function Base.show(io::IO, obj::Instance)
    print(io, "<Instance $(obj.class.name)>")
end

# ---- Generic Functions and Methods ----

struct MMethod
    name::Symbol
    body::Function
    params::Vector{Tuple{Symbol, MClass}}
end

function class_of(_::MMethod)::MClass
    MultiMethod
end

function Base.show(io::IO, m::MMethod)
    print(io, "<Method $(m.name) $(m.params)>")
end

struct MGenericFunction
    name::Symbol
    params::Vector{Symbol}
    methods::Vector{MMethod}
end

function class_of(_::MGenericFunction)::MClass
    GenericFunction
end

function (f::MGenericFunction)(; args...)::Any
    if length(f.methods) == 0
        error("No aplicable method for function $(f.name) with arguments $(args)")
    end

    methods = sort(f.methods, by = x -> length(x.params))
    # TODO: compute the most specific method
    # note: needs class precedence list to work?
end

function Base.show(io::IO, f::MGenericFunction)
    print(io, "<GenericFunction $(f.name) with $(len(f.methods)) methods>")
end

# TODO: @defgeneric name(params)

# TODO: @defmethod name(typed_params) = body
# note: should have the same params as the generic function
# note: an omited param means that its typed as Top
# note: if the corresponding generic function doesnt exist, it should be created

end # module Jos
