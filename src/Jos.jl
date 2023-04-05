module Jos

# ---- Internal Representation ----

mutable struct MClass
    name::Symbol
    cpl::Vector{MClass}
    slots::Vector{Symbol}
    defaulted::Dict{Symbol,Any}
    meta::Union{Nothing,MClass}
    direct_slots::Vector{Symbol}
    direct_superclasses::Vector{MClass}
end

struct MInstance
    class::MClass
    slots::Dict{Symbol,Any}
end

abstract type MGenericFunctionAbstract end

struct MMultiMethod
    procedure::Function
    specializers::Vector{MClass}
    generic_function::Union{Nothing,MGenericFunctionAbstract}
end

struct MGenericFunction <: MGenericFunctionAbstract
    name::Symbol
    params::Vector{Symbol}
    methods::Vector{MMultiMethod}
end

# ---- Internal Base Class Constructor ----

function _new_base_class(
    name::Symbol, slots::Vector{Symbol}, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass})
    MClass(name, MClass[], slots, Dict{Symbol,Any}(), nothing, direct_slots, direct_superclasses)
end

# ---- Bootstrapping Initial Base Classes ----

const Top = _new_base_class(:Top, Symbol[], Symbol[], MClass[])

const Object = _new_base_class(:Object, Symbol[], Symbol[], MClass[Top])

const Class = _new_base_class(:Class, collect(fieldnames(MClass)), collect(fieldnames(MClass)), MClass[Object])

Top.meta = Class
Top.cpl = MClass[Top]

Object.meta = Class
Object.cpl = MClass[Object, Top]

Class.meta = Class
Class.cpl = MClass[Class, Object, Top]

# ---- Internal Compute Class Precedence List ----

function _compute_cpl(cls::MClass)::Vector{MClass}
    function aux(superclasses::Vector{MClass}, cpl::Vector{MClass})::Vector{MClass}
        if length(superclasses) == 0
            cpl
        else
            indirect = MClass[]
            for superclass in superclasses
                if !(superclass in cpl)
                    push!(cpl, superclass)
                    indirect = union(indirect, superclass.direct_superclasses)
                end
            end
            aux(indirect, cpl)
        end
    end

    aux(cls.direct_superclasses, [cls])
end

# ---- Internal Compute Class Slots ----

function _compute_slots(cls::MClass)::Vector{Symbol}
    union([superclass.direct_slots for superclass in cls.cpl]...)
end

# ---- Internal Compute Class Defaulted Slots ----

function _compute_defaulted(cls::MClass)::Dict{Symbol,Any}
    Dict{Symbol,Any}([slot => value for superclass in reverse(cls.cpl) for (slot, value) in superclass.defaulted])
end

# ---- Internal Default Class Constructor ----

function _new_default_class(
    name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass}, meta::MClass=Class)::MClass
    cls = MClass(name, MClass[], Symbol[], Dict{Symbol,Any}(), meta, direct_slots, direct_superclasses)
    cls.cpl = _compute_cpl(cls)
    cls.slots = _compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)
    cls
end

# ---- Remaining Classes ----

const BuiltInClass = _new_default_class(:BuiltInClass, Symbol[], MClass[Class])

const MultiMethod = _new_default_class(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Object])

const GenericFunction = _new_default_class(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[Object])

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

function class_of(obj::MInstance)::MClass
    Base.getfield(obj, :class)
end

function class_of(_::MMultiMethod)::MClass
    MultiMethod
end

function class_of(_::MGenericFunction)::MClass
    GenericFunction
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
    elseif isnothing(match(r"^[a-z]([a-z]+[_]?)*[a-z]$", String(form.args[1])))
        # Starts with 2 or more letters, no more than one underscore in a row and only lower case letters
        error("Generic Function name must contain only lowercase letters and underscores.")
    end

    local name, args

    try
        name = form.args[1]
        args = form.args[2:end]
    catch err
        error("Invalid syntax. Use: @defgeneric function_name(arg1, arg2, ...)", "\n", err)
    end

    if length(args) < 1
        error("Generic Function must have at least one argument.")
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
        error("Invalid syntax. Use: @defmethod function_name(arg1::Class1, arg2::Class2, ...)", "\n", err)
    end

    local gf_args = Symbol[]
    local specializers = Symbol[]

    for arg in arguments
        try
            if arg.head == :(::)
                push!(gf_args, arg.args[1])
                push!(specializers, arg.args[2])
            else
                error("Invalid syntax. Use: @defmethod function_name(arg1::Class1, arg2::Class2, ...)")
            end
        catch
            push!(gf_args, arg)
            push!(specializers, Top.name)
        end
    end

    quote
        # Checking if the generic function is defined
        if !@isdefined($gf_name)
            @defgeneric $gf_name($(gf_args...))
        elseif length($(gf_name).params) != length($(gf_args))
            # If gf was already defined, check if the number of arguments of the method is the same as the gf
            error("GenericFunction '$($(gf_name))' expects $(length($(gf_name).params)) arguments, but $(length($gf_args)) were given!")
        end
        # Specializing the method
        _add_method($(gf_name), [$(specializers...)], (call_next_method::Function, $(gf_args...)) -> $(form.args[2]))
    end
end

# ---- Generic Functions Calling ----

@defmethod no_applicable_method(gf::GenericFunction, args) =
    error("No applicable method for function $(gf.name) with arguments($(join([class_of(arg).name for arg in args], ", ")))")

function specificity(mm::MMultiMethod, args)
    res = 0
    for (i, specializer) in enumerate(mm.specializers)
        res = res * 10 + findfirst(x -> x === specializer, class_of(args[i]).cpl)
    end
    -res
end

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

    # If there are no applicable methods, call no_applicable_method
    if length(applicable_methods) == 0
        no_applicable_method(gf, collect(args))
    else
        # Sorting applicable methods by specificity
        sort!(applicable_methods, by=mm -> specificity(mm, args), rev=true)

        # Call Next Method Closure
        method_idx = 1
        function call_next_method()
            if method_idx == length(applicable_methods)
                no_applicable_method(gf, collect(args))
            else
                applicable_methods[method_idx+=1].procedure(call_next_method, args...)
            end
        end

        # Call the most specific method
        applicable_methods[1].procedure(call_next_method, args...)
    end
end

# ---- Class Instatiation Protocol ----

@defmethod allocate_instance(cls::Class) = begin
    if cls === Top
        error("Cannot instantiate Top class.")
    elseif cls === GenericFunction
        MGenericFunction("Null", Symbol[], MMultiMethod[])
    elseif cls === MultiMethod
        MMultiMethod((call_next_method) -> nothing, MClass[], nothing)
    elseif cls === Class
        MClass(:Null, MClass[], Symbol[], Dict{Symbol,Any}(), nothing, Symbol[], MClass[])
    else
        MInstance(cls, Dict())
    end
end

@defmethod initialize(gf::GenericFunction, initargs) = begin
    for (k, v) in initargs
        if !(k in GenericFunction.slots)
            error("Invalid slot name: $k")
        else
            Base.setproperty!(gf, k, v)
        end
    end
end

@defmethod initialize(mm::MultiMethod, initargs) = begin
    for (k, v) in initargs
        if !(k in MultiMethod.slots)
            error("Invalid slot name: $k")
        else
            Base.setproperty!(mm, k, v)
        end
    end
end

@defmethod initialize(class::Class, initargs) = begin
    for (k, v) in initargs
        if !(k in Class.slots)
            error("Invalid slot name: $k")
        else
            Base.setproperty!(class, k, v)
        end
    end
end

@defmethod initialize(obj::Object, initargs) = begin
    slots = Base.getfield(obj, :slots)
    for (k, v) in class_of(obj).defaulted
        slots[k] = v
    end

    for (k, v) in initargs
        if !(k in class_of(obj).slots)
            error("Invalid slot name: $k")
        end
        slots[k] = v
    end

    for slot in class_of(obj).slots
        if !haskey(slots, slot)
            error("Slot '$slot' not filled.")
        end
    end
end

function new(cls::MClass; kwargs...)
    if length(kwargs) > length(cls.slots)
        error("Too many arguments")
    elseif length(kwargs) < (length(cls.slots) - length(cls.defaulted))
        error("Too few arguments")
    else
        instance = allocate_instance(cls)
        initialize(instance, kwargs)
        instance
    end
end

# ---- Compute Slots Protocol ----

@defgeneric compute_slots(cls)

# ---- Slot Access Protocol ----

# TODO: slot access protocol
# DUVIDA: isto tem mesmo de levar o idx?
@defgeneric compute_getter_and_setter(cls, slotname, slotindex)


#@defmethod compute_getter_and_setter(cls::MInstance, slotname::Symbol, slotindex::Int) = begin
#
#    getter(cls::MInstance) = cls.slots[slotindex]
#
#    setter(cls::MInstance, newval) = (cls.slots[slotindex] = newval)

    # Return the tuple of non-generic functions
#    return (getter, setter)
#end

#@defmethod compute_getter_and_setter(cls::MClass, slotname::Symbol, slotindex::Int) = begin

#    getter(cls::MClass) = cls.slots[slotindex]

#    setter(cls::MClass, newval) = (cls.slots[slotindex] = newval)
    # Return the tuple of non-generic functions
#    return (getter, setter)
#end

function Base.getproperty(obj::MInstance, name::Symbol)
    # TODO: this should call some generic function for
    # implementing the slot access protocol
    slots = Base.getfield(obj, :slots)
    if haskey(slots, name)
        slots[name]
    else
        error("Invalid slot name: $name")
    end
end

function Base.setproperty!(obj::MInstance, name::Symbol, value)
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
    Base.getfield(cls, name)
end

# ---- Compute Class Precedence List Protocol ----

@defgeneric compute_cpl(cls)
# compute_cpl = MGenericFunction(:compute_cpl, Symbol[:cls], MMultiMethod[])
# _add_method(compute_cpl, MClass[Class], (cls) -> _compute_cpl(cls))

# ---- print-object Generic Function and respective Base.show specializations ----

@defmethod print_object(obj::Object, io) =
    print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>")

function Base.show(io::IO, obj::MInstance)
    print_object(obj, io)
end

@defmethod print_object(cls::Class, io) =
    print(io, "<$(class_name(class_of(cls))) $(class_name(cls))>")

function Base.show(io::IO, cls::MClass)
    print_object(cls, io)
end

@defmethod print_object(mm::MultiMethod, io) =
    print(io, "<MultiMethod $(mm.generic_function.name)($(join([specializer.name for specializer in mm.specializers], ", ")))>")

function Base.show(io::IO, mm::MMultiMethod)
    print_object(mm, io)
end

@defmethod print_object(gf::GenericFunction, io) =
    print(io, "<$(class_name(class_of(gf))) $(gf.name) with $(length(gf.methods)) method$(length(gf.methods) > 1 || length(gf.methods) == 0 ? "s" : "")>")

function Base.show(io::IO, gf::MGenericFunction)
    print_object(gf, io)
end

# ---- Define Class Macro ----

#arguments are not corret?
macro defclass(classname, supers=[:Object], slots=Symbol[])

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
            instance = MInstance($(classname), Dict{Symbol,Any}())
            for (k, v) in zip(slots, args)
                instance.slots[k] = v
            end
            instance
        end
    end
end

end # module Jos