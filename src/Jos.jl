module Jos

# ---- Internal Structs ----

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

# ---- Base ----

Top = MClass(:Top, Symbol[], MClass[])

Object = MClass(:Object, Symbol[], MClass[Top])

Class = MClass(:Class, collect(fieldnames(MClass)), MClass[Object])

MultiMethod = MClass(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Top])

GenericFunction = MClass(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[MultiMethod])


BuiltInClass = MClass(:BuiltInClass, Symbol[], MClass[Class])

_Int64 = MClass(:_Int64, Symbol[:value], MClass[BuiltInClass])

_String = MClass(:_String, Symbol[:value], MClass[BuiltInClass])

# ---- Classes ----

function Base.getproperty(cls::MClass, name::Symbol)
    if name === :slots
        if cls === Class
            return cls.direct_slots
        else
            # TODO: add inherited slots
            return cls.direct_slots
        end
    else
        return Base.getfield(cls, name)
    end
end

function class_name(cls::MClass)::Symbol
    cls.name
end

function class_slots(cls::MClass)::Vector{Symbol}
    # TODO: add inherited slots
    cls.direct_slots
end

function class_direct_slots(cls::MClass)::Vector{Symbol}
    cls.direct_slots
end

function class_direct_superclasses(cls::MClass)::Vector{MClass}
    cls.direct_superclasses
end

# ---- Instances ----

function new(class::MClass; args...)::Instance
    if length(args) != length(class.direct_slots)
        error("Invalid number of slots")
    end

    slots = Dict{Symbol,Any}()
    # TODO: handle inherited slots!
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

function method_specializers(mm::MMultiMethod)::Vector{MClass}
    mm.specializers
end

# ---- Generic Functions ----

function (f::MGenericFunction)(; args...)::Any
    if length(f.methods) == 0
        error("No aplicable method for function $(f.name) with arguments $(args)")
    end
    # TODO: compute the most specific method
    # note: needs class precedence list to work?
    # TODO: get the applicable methods
end

function generic_methods(gf::MGenericFunction)::Vector{MMultiMethod}
    gf.methods
end

# ---- Pre-Defined Generic Functions ----

print_object = MGenericFunction(:print_object, Symbol[:obj, :io], MMultiMethod[])

# push!(print_object.methods, MMultiMethod((obj, io) -> print(io,
#         "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>"), MClass[Object, Top]))

# ---- Class Of ----

function class_of(_::MClass)::MClass
    Class
end

function class_of(obj::Instance)::MClass
    Base.getfield(obj, :class)
end

function class_of(_::MMultiMethod)::MClass
    MultiMethod
end

function class_of(_::MGenericFunction)::MClass
    GenericFunction
end

end # module Jos