module Jos

struct MClass
    name::Symbol
    direct_slots::Vector{Symbol}
    direct_superclasses::Vector{MClass}
end

struct Instance
    class::MClass
    slots::Dict{Symbol,Any}
end

struct MMultiMethod
    procedure::Function
    generic_function::Any
    specializers::Vector{MClass}
end

struct MGenericFunction
    name::Symbol
    params::Vector{Symbol}
    methods::Vector{MMultiMethod}
end

# ---- Classes ----

Top = MClass(:Top, Symbol[], MClass[])

Object = MClass(:Object, Symbol[], MClass[Top])

Class = MClass(:Class, collect(fieldnames(MClass)), MClass[Object])

MultiMethod = MClass(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Top])

GenericFunction = MClass(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[MultiMethod])


BuiltInClass = MClass(:BuiltInClass, Symbol[], MClass[Class])

_Int64 = MClass(:_Int64, Symbol[:value], MClass[BuiltInClass])

_String = MClass(:_String, Symbol[:value], MClass[BuiltInClass])


function class_of(_::MClass)::MClass
    Class
end

function Base.getproperty(cls::MClass, name::Symbol)
    if name === :slots
        return collect(fieldnames(MClass))
    else
        return Base.getfield(cls, name)
    end
end

# TODO:
# @defclass(name, super, slots)
# note: if super is [], then super = [Object]

# ---- Instances ----

function class_of(obj::Instance)::MClass
    Base.getfield(obj, :class)
end

function new(class::MClass; args...)::Instance
    if length(args) != length(class.direct_slots)
        error("Invalid number of slots")
    end

    slots = Dict{Symbol,Any}()
    # TODO: handle inherited slots ???
    for (k, v) in args
        if !(k in class.direct_slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end
    Instance(class, slots)
end

function Base.getproperty(obj::Instance, name::Symbol)
    slots = Base.getfield(obj, :slots)
    if haskey(slots, name)
        return slots[name]
    else
        error("Invalid slot name: $name")
    end
end

function Base.setproperty!(obj::Instance, name::Symbol, value)
    slots = Base.getfield(obj, :slots)
    if haskey(slots, name)
        slots[name] = value
    else
        error("Invalid slot name: $name")
    end
end

# ---- Multi Methods ----

function class_of(_::MMultiMethod)::MClass
    MultiMethod
end

# ---- Generic Functions ----

function class_of(_::MGenericFunction)::MClass
    GenericFunction
end

function (f::MGenericFunction)(; args...)::Any
    if length(f.methods) == 0
        error("No aplicable method for function $(f.name) with arguments $(args)")
    end

    # TODO: compute the most specific method
    # note: needs class precedence list to work?
    # TODO: get the applicable methods
end

# TODO: @defgeneric name(params)

# TODO: @defmethod name(typed_params) = body
# note: should have the same params as the generic function
# note: an omited param means that its typed as Top
# note: if the corresponding generic function doesnt exist, it should be created

# ---- Pre-Defined Generic Functions ----

print_object = MGenericFunction(:print_object, Symbol[:obj, :io], MMultiMethod[])

# push!(print_object.methods, MMultiMethod((obj, io) -> print(io,
#         "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>"), MClass[Object, Top]))

end # module Jos
