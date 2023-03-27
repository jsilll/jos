module Jos

# ---- Internal Representation ----
mutable struct MClass
    name::Symbol
    cpl::Vector{MClass}
    slots::Vector{Symbol}
    meta::Union{MClass,Missing}
    defaulted::Dict{Symbol,Any}
    direct_slots::Vector{Symbol}
    direct_superclasses::Vector{MClass}

    MClass(name::Symbol, meta::Union{MClass,Missing}, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass}) =
        new(name, MClass[], Symbol[], meta, Dict{Symbol,Any}(), direct_slots, direct_superclasses)
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

# ---- Internal Base Class Constructor ----
function _new_base_class(name::Symbol, cpl::Vector{MClass}, slots::Vector{Symbol}, defaulted::Dict{Symbol,Any}, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass})
    cls = MClass(name, missing, direct_slots, direct_superclasses)
    cls.cpl = cpl
    cls.slots = slots
    cls.defaulted = defaulted

    cls
end

# ---- Initial Base Classes ----
const Top = _new_base_class(:Top, MClass[], Symbol[], Dict{Symbol,Any}(), Symbol[], MClass[])

const Object = _new_base_class(:Object, MClass[Top], Symbol[], Dict{Symbol,Any}(), Symbol[], MClass[Top])

const Class = _new_base_class(:Class, MClass[Object], collect(fieldnames(MClass)), Dict{Symbol,Any}(), collect(fieldnames(MClass)), MClass[Object])

# -- Set Meta Classes --
Top.meta = Class
Class.meta = Class
Object.meta = Class

# ---- Internal Compute Class Precedence List ----
function _compute_cpl(cls::MClass)::Vector{MClass}
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

# ---- Internal Compute Class Slots ----
function _compute_slots(cls::MClass)::Vector{Symbol}
    slots = Symbol[]
    for superclass in cls.cpl
        slots = union(slots, superclass.direct_slots)
    end

    slots
end

# ---- Internal Compute Class Defaulted Slots ----
function _compute_defaulted(cls::MClass)::Dict{Symbol,Any}
    defaulted = Dict{Symbol,Any}()
    for superclass in reverse(cls.cpl)
        for (slot, value) in superclass.defaulted
            defaulted[slot] = value
        end
    end

    defaulted
end

# ---- Internal Default Class Constructor ----
function _new_default_class(name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass})::MClass
    cls = MClass(name, Class, direct_slots, direct_superclasses)
    cls.cpl = _compute_cpl(cls)
    cls.slots = _compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)

    cls
end

# ---- Remaining Base Classes ----
const MultiMethod = _new_default_class(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Object])

const GenericFunction = _new_default_class(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[Object])

const BuiltInClass = _new_default_class(:BuiltInClass, Symbol[], MClass[Class])

# ---- Built-in Classes ---
const _Int64 = _new_default_class(:_Int64, [:value], MClass[Object])

const _String = _new_default_class(:_String, [:value], MClass[Object])

# ---- Class-Of Non Generic Function ----
function class_of(_)::MClass
    Top
end

function class_of(cls::MClass)::MClass
    cls.meta
end

function class_of(_::MMultiMethod)::MClass
    MultiMethod
end

function class_of(_::MGenericFunction)::MClass
    GenericFunction
end

function class_of(obj::Instance)::MClass
    Base.getfield(obj, :class)
end

# ---- Class-Related Non-Generic Functions ----
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

# ---- MultiMethod-Related Non-Generic Functions ----
function method_specializers(mm::MMultiMethod)::Vector{MClass}
    mm.specializers
end

# ---- Internal Add Method ----
function _add_method(gf::MGenericFunction, specializers::Vector{MClass}, f::Function)::Nothing
    mm = MMultiMethod(f, specializers, gf)
    push!(gf.methods, mm)
    nothing
end

# ---- GenericFunction-Related Non-GenericFunctions ----
function generic_methods(gf::MGenericFunction)::Vector{MMultiMethod}
    gf.methods
end

# ---- Generic Function and Method Macros ----
macro defgeneric(form)
    if form.head != :call
        error("Invalid @defgeneric syntax. Use: @defgeneric function_name(arg1, arg2, ...)")
    end

    # Only lowercase letters and underscores | No more than one underscore in a row | Starts with 2 or more letters
    name = match(r"^[a-z]([a-z]+[_]?)*[a-z]$", String(form.args[1]))

    if isnothing(name)
        error("Function name must contain only lowercase letters and underscores.")
    end

    name = form.args[1]

    if isdefined(Jos, name)
        @warn("WARNING: '$name' already defined. Overwriting with new definition.")
    end

    arguments = form.args[2:end]

    return :( global $name = MGenericFunction($(Expr(:quote, name)), $arguments, MMultiMethod[]) )
end

macro defmethod(form)
    # @defgeneric()
end

# ---- Generic Functions Calling ----

# TODO: @defmethod no_applicable_method, Default behavior is to throw an error
# ERROR: No applicable method for function add with arguments (123, 456)

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
        applicable_methods[current+=1].procedure(call_next_method, args...)
        # TODO: if no more methods, call no_applicable_method()
    end

    # DUVIDA: call_next_method(gf, args...)
    applicable_methods[1].procedure(call_next_method, args...)
end

# ---- Class Instatiation Protocol ----
# -- allocate_instance --
# creates a non-initialized instance of a class
# @defmethod allocate_instance(class::Class) = ???

# -- initialize_instance --
# initializes an instance of a class
# new(class; initargs...) =
# let instance = allocate_instance(class)
# initialize_instance(instance; initargs...)
# instance
# end
# @defmethod initialize(object::Object, initargs) = ???
# @defmethod initialize(class::Class, initargs) = ???
# @defmethod initialize(generic::GenericFunction, initargs) = ???
# @defmethod initialize(method::MultiMethod, initargs) = ???

function new(cls::MClass; kwargs...)::Instance
    # TODO: this should call some generic function for
    # implementing the class instantiation protocol
    if length(kwargs) > length(cls.slots)
        error("Too many arguments")
    end

    if length(kwargs) < (length(cls.slots) - length(cls.defaulted))
        error("Too few arguments")
    end

    slots = copy(cls.defaulted)
    for (k, v) in kwargs
        if !(k in cls.slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end

    # Checking that all slots are filled
    # (i.e. no missing not defaulted slots)
    for slot in cls.slots
        if !haskey(slots, slot)
            error("Missing slot: $slot")
        end
    end

    Instance(cls, slots)
end

# ---- Compute Slots Protocol ----

# ---- Slot Access Protocol ----
# TODO: slot access protocol

function Base.getproperty(obj::Instance, name::Symbol)
    # TODO: this should call some generic function for
    # implementing the slot access protocol
    slots = Base.getfield(obj, :slots)
    if haskey(slots, name)
        return slots[name]
    else
        error("Invalid slot name: $name")
    end
end

function Base.setproperty!(obj::Instance, name::Symbol, value)
    # TODO: this should call some generic function for
    # implementing the slot access protocol
    slots = Base.getfield(obj, :slots)
    if haskey(slots, name)
        slots[name] = value
    else
        error("Invalid slot name: $name")
    end
end

function Base.getproperty(cls::MClass, name::Symbol)
    # TODO: this should call some generic function for
    # implementing the slot access protocol
    return Base.getfield(cls, name)
end

# ---- Compute Class Precedence List Protocol ----
# compute_cpl = MGenericFunction(:compute_cpl, Symbol[:cls], MMultiMethod[])
# _add_method(compute_cpl, MClass[Class], (cls) -> _compute_cpl(cls))

# ---- Remaining Pre-Defined Generic Functions ----
# -- print_object --
# TODO: especializar print_object para outros tipos
# DUVIDA: o primeiro argumento pode ser typed com Top?
print_object = MGenericFunction(:print_object, Symbol[:obj, :io], MMultiMethod[])
_add_method(print_object, MClass[Object, Top], (obj, io::IO) -> print(io,
    "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>"))
# TODO: @defmethod print_object(class::Class, io) =
#         print(io, "<$(class_name(class_of(class))) $(class_name(class))>")
# TODO: MultiMethod
# TODO: GenericFunction

function Base.show(io::IO, cls::MClass)
    print_object(cls, io)
end

function Base.show(io::IO, obj::Instance)
    print_object(obj, io)
end

function Base.show(io::IO, mm::MMultiMethod)
    print_object(mm, io)
end

function Base.show(io::IO, gf::MGenericFunction)
    print_object(gf, io)
end

# ---- Remaining Macros ----
macro defclass(form)
    if @isdefined(name)
        @warn("WARNING: '$name' already defined. Overwriting with new definition.")
    end
end

end # module Jos