module Jos

# ---- Internal Representation ----
mutable struct MClass
    name::Symbol
    meta::MClass
    cpl::Vector{MClass}
    slots::Vector{Symbol}
    defaulted::Dict{Symbol,Any}
    direct_slots::Vector{Symbol}
    direct_superclasses::Vector{MClass}

    function MClass(name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass})
        cls = new()

        cls.name = name
        cls.meta = cls
        cls.cpl = MClass[]
        cls.slots = Symbol[]
        cls.defaulted = Dict{Symbol,Any}()
        cls.direct_slots = direct_slots
        cls.direct_superclasses = direct_superclasses

        cls
    end
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
function _new_base_class(name::Symbol, slots::Vector{Symbol}, defaulted::Dict{Symbol,Any}, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass})
    cls = MClass(name, direct_slots, direct_superclasses)

    cls.slots = slots
    cls.defaulted = defaulted

    cls
end

# ---- Bootstrapping Initial Base Classes ----
const Top = _new_base_class(:Top, Symbol[], Dict{Symbol,Any}(), Symbol[], MClass[])

const Object = _new_base_class(:Object, Symbol[], Dict{Symbol,Any}(), Symbol[], MClass[Top])

const Class = _new_base_class(:Class, collect(fieldnames(MClass)), Dict{Symbol,Any}(), collect(fieldnames(MClass)), MClass[Object])

# -- Set Class Precedence List --
Top.cpl = MClass[Top]
Object.cpl = MClass[Object, Top]
Class.cpl = MClass[Class, Object, Top]

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
function _new_default_class(name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass}, meta::MClass=Class)::MClass
    cls = MClass(name, direct_slots, direct_superclasses)

    cls.meta = meta
    cls.cpl = _compute_cpl(cls)
    cls.slots = _compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)

    cls
end

# ---- Remaining Classes ----
const MultiMethod = _new_default_class(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Object])

const GenericFunction = _new_default_class(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[Object])

const BuiltInClass = _new_default_class(:BuiltInClass, Symbol[], MClass[Class])

# ---- Built-in Classes ---
const _Int64 = _new_default_class(:_Int64, Symbol[], MClass[Object], BuiltInClass)

const _String = _new_default_class(:_String, Symbol[], MClass[Object], BuiltInClass)

# ---- Class-Of Non Generic Function ----
function class_of(_)::MClass
    Top
end

function class_of(_::Int64)::MClass
    _Int64
end

function class_of(_::String)::MClass
    _String
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

# ---- GenericFunction-Related Non-Generic Functions ----
function generic_methods(gf::MGenericFunction)::Vector{MMultiMethod}
    gf.methods
end

# ---- Internal Add Method ----
function _add_method(gf::MGenericFunction, specializers::Vector{MClass}, f::Function)::Nothing
    mm = MMultiMethod(f, specializers, gf)
    push!(gf.methods, mm)
    nothing
end

# ---- Generic Function Macro ----
macro defgeneric(form)
    if form.head != :call
        error("Invalid @defgeneric syntax. Use: @defgeneric function_name(arg1, arg2, ...)")
    end

    # Starts with 2 or more letters, no more than one underscore in a row and only lower case letters
    if isnothing(match(r"^[a-z]([a-z]+[_]?)*[a-z]$", String(form.args[1])))
        error("Generic Function name must contain only lowercase letters and underscores.")
    end

    name = form.args[1]
    args = form.args[2:end]

    if length(args) < 1
        error("A Generic Function must have at least one argument!")
    end

    quote
        # Checking if the name has already been defined
        if @isdefined($name)
            @error("Generic Function '$($name.name)' already defined!")
        else
            global $name = MGenericFunction($(Expr(:quote, name)), $args, MMultiMethod[])
        end
    end
end

# ---- Method Definition Macro ----
# Question: New method with same specializers as an existing one. What should happen?
macro defmethod(form)
    local gf_name, arguments

    try
        gf_name = form.args[1].args[1]
        arguments = form.args[1].args[2:end]

    catch err
        error("Index out of bounds!", "\n", err)
    end

    gf_args = Symbol[]
    specializers = Symbol[]

    for arg in arguments
        try
            if arg.head == :(::)
                push!(gf_args, arg.args[1])
                push!(specializers, arg.args[2])
            end
        catch
            push!(gf_args, arg)
            push!(specializers, Top)
        end
    end

    quote
        # Checking if the generic function is defined
        if !@isdefined($gf_name)
            @defgeneric $gf_name($(gf_args...))
            println("Generic Function '$($gf_name)' was automatically created!")
        else
            # If gf was already defined, check if the number of arguments of the method is the same as the gf
            if length($(gf_name).params) != length($(gf_args))
                error("GF '$($(gf_name))' expects $(length($(gf_name).params)) arguments, but $(length($gf_args)) were given!")
            end
        end

        _add_method($gf_name, MClass[$(specializers...)], (call_next_method::Function, $(gf_args...)) -> $(form.args[2]))
        println("Method added to GF '$($(gf_name))' with specializers: $($(specializers...))")
    end
end


# ---- Generic Functions Calling ----
@defgeneric no_applicable_method(gf, args)

# DUVIDA: Como deve ficar o specializer de args?
_add_method(no_applicable_method, MClass[GenericFunction, Top],
    (call_next_method::Function, gf::MGenericFunction, args) ->
        error("No applicable method for function $(gf.name) with arguments ($(join([class_of(arg).name for arg in args], ", ")))"))

function (gf::MGenericFunction)(args...)
    # Getting applicable methods
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
        no_applicable_method(gf, collect(args))
    end

    # Sorting applicable methods by specificity
    sort!(applicable_methods, by=mm -> begin
            res = 0
            cpls = [class_of(arg).cpl for arg in args]
            for (i, specializer) in enumerate(mm.specializers)
                res = res * 10 + findfirst(x -> x === specializer, cpls[i])
            end
            -res
        end, rev=true)

    # Calling applicable methods
    method_idx = 1
    function call_next_method()
        if method_idx == length(applicable_methods)
            no_applicable_method(gf, collect(args))
        else
            applicable_methods[method_idx+=1].procedure(call_next_method, args...)
        end
    end
    applicable_methods[1].procedure(call_next_method, args...)
end

# ---- Class Instatiation Protocol ----
@defgeneric allocate_instance(cls)

_add_method(allocate_instance, MClass[Class], (cls) -> Instance(cls, Dict()))

# -- initialize_instance --
# TODO:
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
@defgeneric compute_slots(cls)

# ---- Slot Access Protocol ----
# TODO: slot access protocol
# DUVIDA: isto tem mesmo de levar o idx?
@defgeneric compute_getter_and_setter(cls, slot)

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
@defgeneric compute_cpl(cls)
# compute_cpl = MGenericFunction(:compute_cpl, Symbol[:cls], MMultiMethod[])
# _add_method(compute_cpl, MClass[Class], (cls) -> _compute_cpl(cls))

# ---- print-object Generic Function and respective Base.show specializations ----
@defgeneric print_object(obj, io)

_add_method(print_object, MClass[Object, Top],
    (call_next_method::Function, obj::Instance, io::IO) ->
        print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>"))

_add_method(print_object, MClass[Class, Top],
    (call_next_method::Function, cls::MClass, io::IO) ->
        print(io, "<$(class_name(class_of(cls))) $(class_name(cls))>"))

_add_method(print_object, MClass[MultiMethod, Top],
    (call_next_method::Function, mm::MMultiMethod, io::IO) ->
        print(io, "<MultiMethod $(mm.generic_function.name)($(join([specializer.name for specializer in mm.specializers], ", ")))>"))

_add_method(print_object, MClass[GenericFunction, Top],
    (call_next_method::Function, gf::MGenericFunction, io::IO) ->
        print(io,
            "<$(class_name(class_of(gf))) $(gf.name) with $(length(gf.methods)) method$(length(gf.methods) > 1 || length(gf.methods) == 0 ? "s" : "")>"))

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

# ---- Define Class Macro ----
#arguments are not corret?
macro defclass(classname, supers=[:Object], slots=Symbol[])

    #esc to use gensym?
    classname = esc(classname)
    supers = esc(supers)
    slots = esc(slots)

    supers_expr = if supers == [:Object]
        quote
            Object
        end
    else
        quote
            ($(supers...))
        end
    end

    cpl_expr = quote
        cpl = MClass[]
        for superclass in direct_superclasses
            if superclass in cpl
                continue
            end
            push!(cpl, superclass)
            cpl = union(cpl, _compute_cpl(superclass))
        end
        cpl
    end

    defaulted_expr = quote
        _compute_defaulted(cls)
    end

    cls_expr = quote
        cls = MClass(name, slots, direct_superclasses)
        cls.meta = meta
        cls.cpl = $cpl_expr
        cls.slots = _compute_slots(cls)
        cls.defaulted = $defaulted_expr
        cls
    end

    global_expr = quote
        $(classname) = $cls_expr
    end

    quote
        meta = Class
        direct_superclasses = $(supers_expr)

        $cls_expr

        $global_expr

        function $(classname)(args...)
            instance = Instance($(classname), Dict{Symbol,Any}())
            for (k, v) in zip(slots, args)
                instance.slots[k] = v
            end
            instance
        end
    end
end

end # module Jos