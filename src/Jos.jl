module Jos

# ---- Internal Structs ----

struct MClass
    name::Symbol
    cpl::Vector{MClass}
    slots::Vector{Symbol}
    defaulted::Dict{Symbol,Any}
    direct_slots::Vector{Symbol}
    direct_superclasses::Vector{MClass}

    MClass(name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass}) =
        new(name, MClass[], Dict{Symbol, Any}(), Symbol[], direct_slots, direct_superclasses)
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

function Base.getproperty(cls::MClass, name::Symbol)
    return Base.getfield(cls, name)
end

function class_name(cls::MClass)::Symbol
    cls.name
end

function class_cpl(cls::MClass)::Vector{MClass}
    cls.cpl
end

function class_slots(cls::MClass)::Vector{Symbol}
    cls.slots
end

function class_direct_slots(cls::MClass)::Vector{Symbol}
    cls.direct_slots
end

function class_direct_superclasses(cls::MClass)::Vector{MClass}
    cls.direct_superclasses
end

# ---- Base Classes ----

Top = MClass(:Top, Symbol[], MClass[])

Object = MClass(:Object, Symbol[], MClass[Top])
Object.cpl = MClass[Object, Top]
Object.slots = Symbol[]

Class = MClass(:Class, collect(fieldnames(MClass)), MClass[Object])
Class.cpl = MClass[Class, Object, Top]
Class.slots = Class.direct_slots

MultiMethod = MClass(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Top])
MultiMethod.cpl = MClass[MultiMethod, Top]
MultiMethod.slots = MultiMethod.direct_slots

GenericFunction = MClass(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[Top])
GenericFunction.cpl = MClass[GenericFunction, Top]
GenericFunction.slots = GenericFunction.direct_slots

BuiltInClass = MClass(:BuiltInClass, Symbol[], MClass[Class])
BuiltInClass.cpl = MClass[BuiltInClass, Class, Object, Top]
BuiltInClass.slots = BuiltInClass.direct_slots

_Int64 = MClass(:_Int64, [:value], MClass[BuiltInClass])
_Int64.cpl = MClass[_Int64, BuiltInClass, Class, Object, Top]
_Int64.slots = _Int64.direct_slots

_String = MClass(:_String, [:value], MClass[BuiltInClass])
_String.cpl = MClass[_String, BuiltInClass, Class, Object, Top]
_String.slots = _String.direct_slots

# ---- Instances ----

function new(cls::MClass; kwargs...)::Instance
    if length(kwargs) < (lengt(cls.slots) - length(cls.defaulted))
        error("Too few arguments")
    end

    if length(kwargs) > length(cls.slots)
        error("Too many arguments")
    end

    slots = cls.defaulted

    for (k, v) in args
        if !(k in cls.slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end
    
    for slot in cls.slots
        if !haskey(slots, slot)
            error("Missing slot: $slot")
        end
    end

    Instance(cls, slots)
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

# ---- MultiMethods ----

function (mm::MMultiMethod)(args...)::Any
    mm.procedure(args...)
end

function method_specializers(mm::MMultiMethod)::Vector{MClass}
    mm.specializers
end

# ---- Generic Functions ----

function (gf::MGenericFunction)(args...)::Any
    # Compute applicable methods
    applicable_methods = MMultiMethod[]
    for method in gf.methods
        is_applicable = true
        for (i, specializer) in enumerate(method.specializers)
            if !(specializer in class_of(args[i]).cpl)
                is_applicable = false
                break
            end
        end

        if is_applicable
            push!(applicable_methods, method)
        end
    end

    if length(applicable_methods) == 0
        error("No aplicable method for function $(gf.name) with arguments $(args)")
    end

    function specificity(mm::MMultiMethod, args::Vector{MClass})::Int
        res = 0
        for (i, specializer) in enumerate(mm.specializers)
            res = res * 10 + findfirst(x -> x === specializer, args[i])
        end
        return -res
    end

    classes = [class_of(arg) for arg in args]    
    sort!(applicable_methods, by=x -> specificity(x, classes), rev=true)

    applicable_methods[1](args...)

    # TODO: call_next_method??
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

# ---- Class Precdence List ----

function compute_cpl(cls::MClass)::Vector{MClass}
    cpl = MClass[cls]

    function compute_cpl_aux(superclass_vector::Vector{MClass})
        indirect_superclasses = MClass[]

        for superclass in superclass_vector
            if superclass in cpl
                continue
            end
            push!(cpl, superclass)
            indirect_superclasses = union(indirect_superclasses, superclass.direct_superclasses)
        end

        if length(indirect_superclasses) > 0
            compute_cpl_aux(indirect_superclasses)
        end
    end

    compute_cpl_aux(cls.direct_superclasses)

    return cpl
end

# ---- Base Macros ----

macro defclass(name, direct_superclasses, direct_slots)
    if @isdefined(name)
        @warn("WARNING: '$name' already defined. Overwriting with new definition.")
    end

    if isempty(superclasses)
        global c = MClass(name,slots,Object)
    else
        global c = MClass(name,slots,superclasses)
    return c
    end
end


end # module Jos