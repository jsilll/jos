module Jos

# ---- Internal Representation ----

mutable struct MClass
    name::Symbol
    cpl::Vector{MClass}
    slots::Vector{Symbol}
    defaulted::Dict{Symbol,Any}
    meta::Union{Nothing,MClass}
    direct_slots::Vector{Symbol}
    meta_slots::Dict{Symbol,Any}
    getters::Dict{Symbol,Function}
    setters::Dict{Symbol,Function}
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

export MClass, MInstance, MMultiMethod, MGenericFunction

# ---- Internal Base Class Constructor ----

function _new_base_class(
    name::Symbol, slots::Vector{Symbol}, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass})
    MClass(name, MClass[], slots, Dict{Symbol,Any}(), nothing, direct_slots, Dict{Symbol,Any}(),
        Dict{Symbol,Function}(), Dict{Symbol,Function}(), direct_superclasses)
end

# ---- Class Getter and Setter ----

function Base.getproperty(cls::MClass, name::Symbol)
    try
        Base.getfield(cls, name)
    catch
        if haskey(cls.meta_slots, name)
            cls.meta_slots[name]
        else
            error("Invalid slot name: $name")
        end
    end
end

function Base.setproperty!(cls::MClass, name::Symbol, value)
    try
        Base.setfield!(cls, name, value)
    catch
        if haskey(cls.meta_slots, name)
            cls.meta_slots[name] = value
        else
            error("Invalid slot name: $name")
        end
    end
end

# ---- Instance Getter and Setter ----

function Base.getproperty(obj::MInstance, slot::Symbol)
    slots = Base.getfield(obj, :slots)
    if haskey(slots, slot)
        class_of(obj).getters[slot](obj)
    else
        error("Invalid slot name: $slot")
    end
end

function Base.setproperty!(obj::MInstance, slot::Symbol, value)
    slots = Base.getfield(obj, :slots)
    if haskey(slots, slot)
        class_of(obj).setters[slot](obj, value)
    else
        error("Invalid slot name: $slot")
    end
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

export Top, Object, Class

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
    vcat(map(cls -> cls.direct_slots, cls.cpl)...)
end

# ---- Internal Compute Class Defaulted Slots ----

function _compute_defaulted(cls::MClass)::Dict{Symbol,Any}
    Dict{Symbol,Any}([slot => value for superclass in reverse(cls.cpl) for (slot, value) in superclass.defaulted])
end

# ---- Internal Compute Meta Slots ----

function _compute_meta_slots(cls::MClass)::Dict{Symbol,Any}
    if cls.meta == Class
        return Dict{Symbol,Any}()
    end

    meta_slots = Dict{Symbol,Any}()

    for slot in cls.meta.slots
        if haskey(cls.meta.defaulted, slot)
            meta_slots[slot] = cls.meta.defaulted[slot]
        else
            meta_slots[slot] = missing
        end
    end

    meta_slots
end

# ---- Internal Compute Class Getter and Setter ----

function _compute_getter(slot::Symbol)::Function
    (obj) -> Base.getfield(obj, :slots)[slot]
end

function _compute_setter(slot::Symbol)::Function
    (obj, value) -> Base.getfield(obj, :slots)[slot] = value
end

# ---- Internal Default Class Constructor ----

function _new_default_class(name::Symbol, direct_slots::Vector{Symbol},
    direct_superclasses::Vector{MClass}, meta::MClass=Class)::MClass
    cls = MClass(name, MClass[], Symbol[], Dict{Symbol,Any}(), meta, direct_slots,
        Dict{Symbol,Any}(), Dict{Symbol,Function}(), Dict{Symbol,Function}(), direct_superclasses)

    cls.cpl = _compute_cpl(cls)
    cls.slots = _compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)
    cls.meta_slots = _compute_meta_slots(cls)

    for slot in cls.slots
        cls.getters[slot] = _compute_getter(slot)
        cls.setters[slot] = _compute_setter(slot)
    end

    cls
end

# ---- Remaining Classes ----

const BuiltInClass = _new_default_class(:BuiltInClass, Symbol[], MClass[Class])

const MultiMethod = _new_default_class(:MultiMethod, collect(fieldnames(MMultiMethod)), MClass[Object])

const GenericFunction = _new_default_class(:GenericFunction, collect(fieldnames(MGenericFunction)), MClass[Object])

export BuiltInClass, MultiMethod, GenericFunction

# ---- Built-in Classes ---

const _Int64 = _new_default_class(:_Int64, Symbol[], MClass[Top], BuiltInClass)

const _String = _new_default_class(:_String, Symbol[], MClass[Top], BuiltInClass)

export _Int64, _String

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

export class_of

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

export class_name, class_cpl, class_slots, class_direct_slots, class_direct_superclasses

# ---- MultiMethod-Related Non-Generic Functions ----

function method_specializers(mm::MMultiMethod)::Vector{MClass}
    mm.specializers
end

export method_specializers

# ---- GenericFunction-Related Non-Generic Functions ----

function generic_methods(gf::MGenericFunction)::Vector{MMultiMethod}
    gf.methods
end

export generic_methods

# ---- Internal Add Method ----

function _add_method(gf::MGenericFunction, specializers::Vector{MClass}, f::Function)::Nothing
    mm = MMultiMethod(f, specializers, gf)

    for method in gf.methods
        if method.specializers == specializers
            method.f = f
        end
    end

    push!(gf.methods, mm)
    nothing
end

export _add_method

# ---- Generic Function Macro ----

macro defgeneric(form)
    if form.head != :call
        error("Invalid @defgeneric syntax. Use: @defgeneric function_name(arg1, arg2, ...)")
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
    else
        esc(quote
            if @isdefined($name)
                @error("Generic Function '$($name.name)' already defined!")
            else
                global $name = MGenericFunction($(Expr(:quote, name)), $args, MMultiMethod[])
            end
        end)
    end
end

export @defgeneric

# ---- Method Definition Macro ----

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

    esc(quote
        if !@isdefined($gf_name)
            @defgeneric $gf_name($(gf_args...))
        elseif length($(gf_name).params) != length($(gf_args))
            error("GenericFunction '$($(gf_name))' expects $(length($(gf_name).params)) arguments, but $(length($gf_args)) were given!")
        end
        _add_method($(gf_name), [$(specializers...)], (call_next_method::Function, $(gf_args...)) -> $(form.args[2]))
    end)
end

export @defmethod

# ---- Generic Functions Calling ----

@defmethod no_applicable_method(gf::GenericFunction, args) =
    error("No applicable method for function $(gf.name) with arguments ($(join(args, ", ")))")

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

export no_applicable_method

# ---- Compute Class Precedence List Protocol ----

@defmethod compute_cpl(cls::Class) = _compute_cpl(cls)

export compute_cpl

# ---- Compute Slots Protocol ----

@defmethod compute_slots(cls::Class) = _compute_slots(cls)

export compute_slots

# ---- Compute Getters and Setters Protocol ----

@defmethod compute_getter_and_setter(_::Class, slot, idx) =
    (_compute_getter(slot), _compute_setter(slot))

export compute_getter_and_setter

# ---- Class Instatiation Protocol ----

@defmethod allocate_instance(cls::Class) = begin
    if cls === Top
        error("Cannot instantiate Top class.")
    elseif cls === GenericFunction
        MGenericFunction("Null", Symbol[], MMultiMethod[])
    elseif cls === MultiMethod
        MMultiMethod((call_next_method) -> nothing, MClass[], nothing)
    elseif cls === Class
        MClass(:Class, MClass[], Symbol[], Dict{Symbol,Any}(), Class, Symbol[],
            Dict{Symbol,Any}(), Dict{Symbol,Function}, Dict{Symbol,Function}, [Object])
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

@defmethod initialize(cls::Class, initargs) = begin
    for (k, v) in initargs
        Base.setproperty!(cls, k, v)
    end

    cls.cpl = compute_cpl(cls)
    cls.slots = compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)
    cls.meta_slots = _compute_meta_slots(cls)

    for (slot, idx) in enumerate(cls.slots)
        cls.getters[slot], cls.setters[slot] = compute_getter_and_setter(cls, slot, idx)
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

export allocate_instance, initialize, new

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

export print_object

# ---- Define Class Macro ----

function _new_class(name::Symbol, direct_slots::Vector{Symbol}, direct_superclasses::Vector{MClass}, meta::MClass=Class)::MClass
    cls = MClass(name, MClass[], Symbol[], Dict{Symbol,Any}(), meta, direct_slots, Dict{Symbol,Any}(),
        Dict{Symbol,Function}(), Dict{Symbol,Function}(), direct_superclasses)

    cls.cpl = compute_cpl(cls)
    cls.slots = compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)
    cls.meta_slots = _compute_meta_slots(cls)

    for slot in cls.slots
        cls.getters[slot], cls.setters[slot] = compute_getter_and_setter(cls, slot, 0)
    end

    cls
end

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

export _new_class, @defclass

end # module Jos