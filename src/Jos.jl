module Jos

# ---- Internal Structs ----

mutable struct MClass
    name::Symbol
    cpl::Vector{MClass}
    slots::Vector{Symbol}
    defaulted::Dict{Symbol,Any}
    direct_slots::Vector{Symbol}
    direct_superclasses::Vector{MClass}

    """
    Creates a new class with the given name, direct slots, and direct superclasses.
    Doesn't compute the class precedence list, the defaulted slots, or the slots.
    """
    MClass(name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass}) =
        new(name, MClass[], Symbol[], Dict{Symbol,Any}(), direct_slots, direct_superclasses)
end

struct Instance
    class::MClass
    slots::Dict{Symbol,Any}
end

abstract type MGenericFunctionAbstract end

struct MMultiMethod
    procedure::Function
    specializers::Vector{MClass}
    generic_function::MGenericFunctionAbstract
end

struct MGenericFunction <: MGenericFunctionAbstract
    name::Symbol
    params::Vector{Symbol}
    methods::Vector{MMultiMethod}
end

# ---- Internal Class Precedence List ----

function _compute_class_cpl(cls::MClass)::Vector{MClass}
    cpl = MClass[cls]

    function aux(superclass_vector::Vector{MClass})
        indirect_superclasses = MClass[]

        for superclass in superclass_vector
            if superclass in cpl
                continue
            end
            push!(cpl, superclass)
            indirect_superclasses = union(indirect_superclasses, superclass.direct_superclasses)
        end

        if length(indirect_superclasses) > 0
            aux(indirect_superclasses)
        end
    end

    aux(cls.direct_superclasses)

    cpl
end

# ---- Internal Class Slots ----

function _compute_class_slots(cls::MClass)::Vector{Symbol}
    slots = Symbol[]
    for superclass in cls.cpl
        slots = union(slots, superclass.direct_slots)
    end

    slots
end

# ---- Internal Class Defaulted Slots ----

function _compute_class_defaulted(cls::MClass)::Dict{Symbol,Any}
    defaulted = Dict{Symbol,Any}()
    for superclass in reverse(cls.cpl)
        for (slot, value) in superclass.defaulted
            defaulted[slot] = value
        end
    end

    defaulted
end

# ---- Internal Class Initialization ----

function _new_base_class(name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass})::MClass
    cls = MClass(name, direct_slots, direct_superclasses)

    cls.cpl = _compute_class_cpl(cls)
    cls.slots = _compute_class_slots(cls)
    cls.defaulted = _compute_class_defaulted(cls)

    cls
end

# ---- Base Classes ----

const Top = _new_base_class(:Top, Symbol[], MClass[])

const Object = _new_base_class(:Object, Symbol[], MClass[Top])

const Class = _new_base_class(:Class, collect(fieldnames(MClass)), MClass[Object])

const MultiMethod = _new_base_class(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Object])

const GenericFunction = _new_base_class(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[Object])

const BuiltInClass = _new_base_class(:BuiltInClass, Symbol[], MClass[Class])

const _Int64 = _new_base_class(:Int64, [:value], MClass[BuiltInClass])

const _String = _new_base_class(:String, [:value], MClass[BuiltInClass])

# ---- Class Of ----

function class_of(_)::MClass
    Top
end

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

# ---- Classes' Methods ----

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

# ---- Instances ----

function new(cls::MClass; kwargs...)::Instance
    # Early check 1 
    if length(kwargs) > length(cls.slots)
        error("Too many arguments")
    end
    
    # Early check 2
    if length(kwargs) < (length(cls.slots) - length(cls.defaulted))
        error("Too few arguments")
    end

    # Filling slots and checking
    # for invalid slot names    
    slots = cls.defaulted
    for (k, v) in kwargs
        if !(k in cls.slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end

    # Checking that all slots are filled
    # (i.e no repeated slot names in kwargs)
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

function Base.setproperty!(obj::Instance, name::Symbol, value)::Nothing
    slots = Base.getfield(obj, :slots)
    if haskey(slots, name)
        slots[name] = value
    else
        error("Invalid slot name: $name")
    end
end

# ---- MultiMethods ----

function method_specializers(mm::MMultiMethod)::Vector{MClass}
    mm.specializers
end

# ---- Generic Functions ----

function _add_method(gf::MGenericFunction, specializers::Vector{MClass}, f::Function)::Nothing
    mm = MMultiMethod(f, specializers, gf)
    push!(gf.methods, mm)
    nothing
end

function (gf::MGenericFunction)(args...; kwargs...)
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

    current = 1
    function call_next_method()
        applicable_methods[current += 1].procedure(call_next_method, args...)
    end

    # DUVIDA: call_next_method(gf, args...)
    applicable_methods[1].procedure(call_next_method, args...)
end

function generic_methods(gf::MGenericFunction)::Vector{MMultiMethod}
    gf.methods
end

# ---- Pre-Defined Generic Functions ----

print_object = MGenericFunction(:print_object, Symbol[:obj, :io], MMultiMethod[])
_add_method(print_object, MClass[Top, Top], (obj, io::IO) -> print(io,
        "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>"))

compute_cpl = MGenericFunction(:compute_cpl, Symbol[:cls], MMultiMethod[])
_add_method(compute_cpl, MClass[Class], (cls) -> _compute_cpl(cls))

# ---- Base Macros ----

macro defclass(form)
    if @isdefined(name)
        @warn("WARNING: '$name' already defined. Overwriting with new definition.")
    end

    # dump(form)

    if isempty(superclasses)
        global c = MClass(name, slots, Object)
    else
        global c = MClass(name, slots, superclasses)
        return c
    end
end

macro defgeneric(form)
end

macro defmethod(form)
    # @defgeneric()
end

end # module Jos