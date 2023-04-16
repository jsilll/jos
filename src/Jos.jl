module Jos

# ---- Internal Representation ----

mutable struct JClass
    name::Symbol
    cpl::Vector{JClass}
    slots::Vector{Symbol}
    defaulted::Dict{Symbol,Any}
    meta::Union{Nothing,JClass}
    direct_slots::Vector{Symbol}
    meta_slots::Dict{Symbol,Any}
    getters::Dict{Symbol,Function}
    setters::Dict{Symbol,Function}
    direct_superclasses::Vector{JClass}
end

struct JInstance
    class::JClass
    slots::Dict{Symbol,Any}
end

abstract type JGenericFunctionAbstract end

struct JMultiMethod
    procedure::Function
    specializers::Vector{JClass}
    generic_function::Union{Nothing,JGenericFunctionAbstract}
end

struct JGenericFunction <: JGenericFunctionAbstract
    name::Symbol
    params::Vector{Symbol}
    methods::Vector{JMultiMethod}
end

export JClass, JInstance, JMultiMethod, JGenericFunction

# ---- Class Getter and Setter ----

function Base.getproperty(cls::JClass, name::Symbol)
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

function Base.setproperty!(cls::JClass, name::Symbol, value)
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

function Base.getproperty(obj::JInstance, slot::Symbol)
    if haskey(Base.getfield(obj, :slots), slot)
        class_of(obj).getters[slot](obj)
    else
        error("Invalid slot name: $slot")
    end
end

function Base.setproperty!(obj::JInstance, slot::Symbol, value)
    if haskey(Base.getfield(obj, :slots), slot)
        class_of(obj).setters[slot](obj, value)
    else
        error("Invalid slot name: $slot")
    end
end

# ---- Internal Base Class Constructor ----

function _new_base_class(name::Symbol, slots::Vector{Symbol},
    direct_superclasses::Vector{JClass})::JClass
    JClass(name,
        JClass[],
        slots,
        Dict{Symbol,Any}(),
        nothing,
        slots,
        Dict{Symbol,Any}(),
        Dict{Symbol,Function}(),
        Dict{Symbol,Function}(),
        direct_superclasses)
end

# ---- Bootstrapping Initial Base Classes ----

const Top = _new_base_class(:Top, Symbol[], JClass[])

const Object = _new_base_class(:Object, Symbol[], [Top])

const Class = _new_base_class(:Class, collect(fieldnames(JClass)), [Object])

Top.meta = Class
Top.cpl = [Top]

Object.meta = Class
Object.cpl = [Object, Top]

Class.meta = Class
Class.cpl = [Class, Object, Top]

export Top, Object, Class

# ---- Internal Compute Class Precedence List ----

function _compute_cpl(cls::JClass)::Vector{JClass}
    function aux(superclasses::Vector{JClass}, cpl::Vector{JClass})::Vector{JClass}
        if length(superclasses) == 0
            cpl
        else
            indirect = JClass[]
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

function _compute_slots(cls::JClass)::Vector{Symbol}
    vcat(map(cls -> cls.direct_slots, cls.cpl)...)
end

# ---- Internal Compute Class Defaulted Slots ----

function _compute_defaulted(cls::JClass)::Dict{Symbol,Any}
    Dict{Symbol,Any}(
        [slot => value
         for superclass in reverse(cls.cpl)
         for (slot, value) in superclass.defaulted])
end

# ---- Internal Compute Meta Slots ----

function _compute_meta_slots(cls::JClass)::Dict{Symbol,Any}
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

function _compute_getter_and_setter(slot::Symbol)::Tuple{Function,Function}
    ((obj) -> Base.getfield(obj, :slots)[slot],
        (obj, value) -> Base.getfield(obj, :slots)[slot] = value)
end

# ---- Internal Default Class Constructor ----

function _new_default_class(name::Symbol, direct_slots::Vector{Symbol},
    direct_superclasses::Vector{JClass}, meta::JClass=Class)::JClass

    cls = JClass(name,
        JClass[],
        Symbol[],
        Dict{Symbol,Any}(),
        meta,
        direct_slots,
        Dict{Symbol,Any}(),
        Dict{Symbol,Function}(),
        Dict{Symbol,Function}(),
        direct_superclasses)

    cls.cpl = _compute_cpl(cls)
    cls.slots = _compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)
    cls.meta_slots = _compute_meta_slots(cls)

    for slot in cls.slots
        cls.getters[slot], cls.setters[slot] = _compute_getter_and_setter(slot)
    end

    cls
end

# ---- Remaining Classes ----

const BuiltInClass = _new_default_class(:BuiltInClass, Symbol[], [Class])

const MultiMethod = _new_default_class(:MultiMethod, collect(fieldnames(JMultiMethod)), [Object])

const GenericFunction = _new_default_class(:GenericFunction, collect(fieldnames(JGenericFunction)), [Object])

export BuiltInClass, MultiMethod, GenericFunction

# ---- Built-in Classes ---

const _Int64 = _new_default_class(:_Int64, Symbol[], [Top], BuiltInClass)

const _String = _new_default_class(:_String, Symbol[], [Top], BuiltInClass)

export _Int64, _String

# ---- Class-Of Non Generic Function ----

function class_of(_)::JClass
    Top
end

function class_of(_::Int64)::JClass
    _Int64
end

function class_of(_::String)::JClass
    _String
end

function class_of(cls::JClass)::JClass
    cls.meta
end

function class_of(obj::JInstance)::JClass
    Base.getfield(obj, :class)
end

function class_of(_::JMultiMethod)::JClass
    MultiMethod
end

function class_of(_::JGenericFunction)::JClass
    GenericFunction
end

export class_of

# ---- Class-Related Non-Generic Functions ----

function class_name(cls::JClass)::Symbol
    cls.name
end

function class_cpl(cls::JClass)::Vector{JClass}
    cls.cpl
end

function class_slots(cls::JClass)::Vector{Symbol}
    cls.slots
end

function class_direct_slots(cls::JClass)::Vector{Symbol}
    cls.direct_slots
end

function class_direct_superclasses(cls::JClass)::Vector{JClass}
    cls.direct_superclasses
end

export class_name, class_cpl, class_slots, class_direct_slots, class_direct_superclasses

# ---- MultiMethod-Related Non-Generic Functions ----

function method_specializers(mm::JMultiMethod)::Vector{JClass}
    mm.specializers
end

export method_specializers

# ---- GenericFunction-Related Non-Generic Functions ----

function generic_methods(gf::JGenericFunction)::Vector{JMultiMethod}
    gf.methods
end

export generic_methods

# ---- Internal Add Method ----

function _add_method(gf::JGenericFunction,
    specializers::Vector{JClass}, f::Function)::Nothing
    mm = JMultiMethod(f, specializers, gf)

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
                global $name = JGenericFunction($(Expr(:quote, name)), $args, JMultiMethod[])
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

function specificity(mm::JMultiMethod, args)
    res = 0
    for (i, specializer) in enumerate(mm.specializers)
        res = res * 10 + findfirst(x -> x === specializer, class_of(args[i]).cpl)
    end
    -res
end

function (gf::JGenericFunction)(args...)
    # Getting applicable methods
    applicable_methods = JMultiMethod[]
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

@defmethod compute_getter_and_setter(cls::Class, slot, idx) = _compute_getter_and_setter(slot)

export compute_getter_and_setter

# ---- Class Instatiation Protocol ----

@defmethod allocate_instance(cls::Class) = begin
    if cls === Top
        error("Cannot instantiate Top class.")
    elseif cls === GenericFunction
        JGenericFunction("Null", Symbol[], JMultiMethod[])
    elseif cls === MultiMethod
        JMultiMethod((call_next_method) -> nothing, JClass[], nothing)
    elseif cls === Class
        JClass(:Class,
            JClass[],
            Symbol[],
            Dict{Symbol,Any}(),
            Class,
            Symbol[],
            Dict{Symbol,Any}(),
            Dict{Symbol,Function},
            Dict{Symbol,Function},
            [Object])
    else
        JInstance(cls, Dict())
    end
end

@defgeneric allocate_instance(instance, initargs)

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
    cls.cpl = compute_cpl(cls)
    cls.slots = compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)
    cls.meta_slots = _compute_meta_slots(cls)

    for (slot, idx) in enumerate(cls.slots)
        cls.getters[slot], cls.setters[slot] = compute_getter_and_setter(cls, slot, idx)
    end

    for (k, v) in initargs
        if !(k in Class.slots)
            error("Invalid slot name: $k")
        else
            Base.setproperty!(cls, k, v)
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
            slots[slot] = missing
        end
    end
end

function new(cls::JClass; kwargs...)
    if length(kwargs) > length(cls.slots)
        error("Too many arguments")
    else
        instance = allocate_instance(cls)
        initialize(instance, kwargs)
        instance
    end
end

export allocate_instance, initialize, new

# ---- print-object Generic Function and respective Base.show specializations ----

@defgeneric print_object(obj, io)

@defmethod print_object(cls::Class, io) =
    print(io, "<$(class_name(class_of(cls))) $(class_name(cls))>")

@defmethod print_object(obj::Object, io) =
    print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>")

@defmethod print_object(mm::MultiMethod, io) =
    print(io, "<MultiMethod $(mm.generic_function.name)($(join([specializer.name for specializer in mm.specializers], ", ")))>")

@defmethod print_object(gf::GenericFunction, io) =
    print(io, "<$(class_name(class_of(gf))) $(gf.name) with $(length(gf.methods)) method$(length(gf.methods) > 1 || length(gf.methods) == 0 ? "s" : "")>")

function Base.show(io::IO, cls::JClass)
    print_object(cls, io)
end

function Base.show(io::IO, obj::JInstance)
    print_object(obj, io)
end

function Base.show(io::IO, mm::JMultiMethod)
    print_object(mm, io)
end

function Base.show(io::IO, gf::JGenericFunction)
    print_object(gf, io)
end

export print_object

# ---- Define Class Macro ----

function _new_class(name::Symbol, direct_slots::Vector{Symbol}, defaulted::Dict{Symbol,Any},
    direct_superclasses::Vector{JClass}, meta::JClass=Class)::JClass

    cls = JClass(name,
        JClass[],
        Symbol[],
        Dict{Symbol,Any}(),
        meta,
        direct_slots,
        Dict{Symbol,Any}(),
        Dict{Symbol,Function}(),
        Dict{Symbol,Function}(),
        direct_superclasses)

    cls.cpl = compute_cpl(cls)
    cls.slots = compute_slots(cls)
    cls.defaulted = _compute_defaulted(cls)
    cls.meta_slots = _compute_meta_slots(cls)

    for slot in cls.slots
        cls.getters[slot], cls.setters[slot] = compute_getter_and_setter(cls, slot, 0)
    end

    for (slot, value) in defaulted
        cls.defaulted[slot] = value
    end

    cls
end

function slots_expr_to_dict(expr)
    slots = Dict[]
    multiple_slots = false

    # Check if the slots have no additional options
    try
        slots_num = length(expr.args)

        for arg in expr.args
            if arg isa Symbol
                push!(slots, Dict{Symbol,Any}(
                    :slot_name => arg,
                    :reader => missing,
                    :writer => missing,
                    :initform => missing))
            end
        end

        if slots_num == length(slots)
            return slots
        else
            slots = Dict[]
        end

    catch
        slots = Dict[]
    end

    # Handle slots with additional options
    function handle_slots(slot)
        d = Dict{Symbol,Any}(
            :slot_name => missing,
            :reader => missing,
            :writer => missing,
            :initform => missing)

        if slot isa Expr
            head = slot.head

            if head == :vect
                for arg in slot.args

                    if arg isa Symbol
                        d[:slot_name] = arg

                    elseif arg.head == :(=)
                        if haskey(d, arg.args[1])
                            d[arg.args[1]] = arg.args[2]

                        elseif !(arg.args[1] in [:reader, :writer, :initform])
                            if !ismissing(d[:slot_name])
                                push!(slots, handle_slots(arg))

                            else
                                d[:slot_name] = arg.args[1]
                                d[:initform] = arg.args[2]
                            end

                        else
                            d[:slot_name] = arg.args[2]
                        end

                    elseif arg.head == :vect
                        push!(slots, handle_slots(arg))
                        multiple_slots = true
                    end

                end

            elseif head == :(=)
                d[:slot_name] = slot.args[1]
                d[:initform] = slot.args[2]
            end

        elseif slot isa Symbol
            d[:slot_name] = slot
        end

        return d
    end

    # Discard the first dict when there 
    # are multiple slots because it's empty
    s = handle_slots(expr)

    if !multiple_slots
        push!(slots, s)
    end

    return slots
end

macro defclass(form_class, form_supers, form_slots, form_meta=nothing)
    local class_name, supers, slots, defaulted, extra_methods

    try
        # Class name
        class_name = form_class

        # Parse slots Exprs to a vector of Dicts
        slots_options = slots_expr_to_dict(form_slots)

        slots = Symbol[]
        for slot in slots_options
            push!(slots, slot[:slot_name])
        end

        supers = form_supers.args

        if length(supers) == 0
            push!(supers, :Object)
        end

        # Defaulted values
        defaulted = Dict{Symbol,Any}()

        # Add to extra_methods if slots have a reader/writer
        extra_methods = []
        for s in slots_options
            if !ismissing(s[:reader])
                push!(extra_methods, :(@defmethod $(s[:reader])(o::$class_name) = o.$(s[:slot_name])))
            end

            if !ismissing(s[:writer])
                push!(extra_methods, :(@defmethod $(s[:writer])(o::$class_name, v) = o.$(s[:slot_name]) = v))
            end

            if !ismissing(s[:initform])
                push!(defaulted, s[:slot_name] => s[:initform])
            end
        end
    catch
        error("Invalid @defclass syntax. Use: @defclass(Name, [Super1, Super2, ...], [Slot1, Slot2, ...])")
    end

    # Check if the metaclass is specified
    meta = Class
    if !isnothing(form_meta)
        try
            if form_meta.head == :(=)
                if form_meta.args[1] == :metaclass
                    meta = form_meta.args[2]
                end
            end
        catch
            error("Invalid syntax for metaclass! Use: metaclass = <metaclass_name>")
        end
    end

    esc(quote
        if !(Class in $(meta).cpl)
            error("Metaclass must be defined and/or a subclass of Class!")
        end
        try
            global $class_name = _new_class($(Expr(:quote, class_name)), $(sort(slots)), $defaulted, JClass[$(supers...)], $meta)
            $(extra_methods...)
        catch e
            error("Error while defining class $class_name: ", e)
        end
    end)
end

export _new_class, @defclass

end # module Jos