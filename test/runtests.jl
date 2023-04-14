using Test, Jos

# ---- Helper Functions ----

function get_print_object_output(c)
    io = IOBuffer()
    print_object(c, io)
    return String(take!(io))
end

# ---- Base Generic Functions ----

@defgeneric add(x, y)

@defgeneric draw(shape, device)

# ---- Base Classes ----

@defmethod add(x::_Int64, y::_Int64) = x + y

@defmethod add(x::_String, y::_String) = x * y

# ---- Complex Numbers Example ----

const ComplexNumber = _new_class(:ComplexNumber, [:real, :imag], [Object])

const c1 = new(ComplexNumber, real=1, imag=2)

const c2 = new(ComplexNumber, real=3, imag=4)

@defmethod add(x::ComplexNumber, y::ComplexNumber) =
    new(ComplexNumber, real=x.real + y.real, imag=x.imag + y.imag)

@defmethod print_object(c::ComplexNumber, io) =
    print(io, "$(c.real)$(c.imag < 0 ? "-" : "+")$(abs(c.imag))i")

# ---- Shapes and Devices Example ----

const Shape = _new_class(:Shape, Symbol[], [Object])

const Line = _new_class(:Line, [:from, :to], [Shape])

const Circle = _new_class(:Circle, [:center, :radius], [Shape])

const Device = _new_class(:Device, Symbol[:color], [Object])

const Screen = _new_class(:Screen, Symbol[], [Device])

const Printer = _new_class(:Printer, Symbol[], [Device])

@defmethod draw(shape::Line, device::Screen) = "Drawing a Line on a Screen"

@defmethod draw(shape::Line, device::Printer) = "Drawing a Line on a Printer"

@defmethod draw(shape::Circle, device::Screen) = "Drawing a Circle on a Screen"

@defmethod draw(shape::Circle, device::Printer) = "Drawing a Circle on a Printer"

# ---- Mixins Example ----

const ColorMixin = _new_class(:ColorMixin, [:color], [Object])

const ColoredLine = _new_class(:ColoredLine, Symbol[], [ColorMixin, Line])

const ColoredCircle = _new_class(:ColoredCircle, Symbol[], [ColorMixin, Circle])

@defmethod draw(shape::ColorMixin, device::Device) =
    let previous_color = device.color
        device.color = shape.color
        action = call_next_method()
        device.color = previous_color
        [shape.color, action, previous_color]
    end

# ---- Counting Class Example ----

const CountingClass = _new_class(:CountingClass, [:counter], [Class])
CountingClass.defaulted = Dict{Symbol,Any}(:counter => 0)

const CountingFoo = _new_class(:CountingFoo, Symbol[], [Object], CountingClass)

const CountingBar = _new_class(:CountingBar, Symbol[], [Object], CountingClass)

@defmethod allocate_instance(class::CountingClass) =
    begin
        class.counter += 1
        call_next_method()
    end

# ---- Collision Avoiding Class Example ----

const AvoidCollisionClass = _new_class(:AvoidCollisionClass, Symbol[], [Class])

@defmethod compute_slots(class::AvoidCollisionClass) =
    let slots = call_next_method()
        duplicates = symdiff(slots, unique(slots))
        isempty(duplicates) ?
        slots :
        error("Multiple occurrences of slots: $(join(map(string, duplicates), ", "))")
    end

const Foo = _new_class(:Foo, [:a, :b], [Object])

const Bar = _new_class(:Bar, [:b, :c], [Object])

const FooBar = _new_class(:FooBar, [:a, :d], [Foo, Bar])

# ---- Undoable Class Example ----

undo_trail = []

save_previous_value = true

current_state() = length(undo_trail)

store_previous(object, slot, value) = push!(undo_trail, (object, slot, value))

restore_state(state) =
    while length(undo_trail) != state
        restore(pop!(undo_trail)...)
    end

restore(object, slot, values) =
    let previous_save_previous_value = save_previous_value
        global save_previous_value = false
        try
            setproperty!(object, slot, values)
        finally
            global save_previous_value = previous_save_previous_value
        end
    end

const UndoableClass = _new_class(:UndoableClass, Symbol[], [Class])

@defmethod compute_getter_and_setter(cls::UndoableClass, slot, idx) =
    let (getter, setter) = call_next_method()
        (getter,
            (o, v) -> begin
                if save_previous_value
                    store_previous(o, slot, getter(o))
                end
                setter(o, v)
            end)
    end

const Person = _new_class(:Person, [:name, :age, :friend], [Object], UndoableClass)

@defmethod print_object(p::Person, io) =
    print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]")

# ---- Flavors Example ----

const FlavorsClass = _new_class(:FlavorsClass, Symbol[], [Class])

@defmethod compute_cpl(cls::FlavorsClass) =
    let depth_first_cpl(class) = [class, foldl(vcat, map(depth_first_cpl, class_direct_superclasses(class)), init=[])...],
        base_cpl = [Object, Top]

        vcat(unique(filter(!in(base_cpl), depth_first_cpl(cls))), base_cpl)
    end

# ---- Multiple Meta-Class Inheritance ----

const UndoableCollisionAvoidingCountingClass =
    _new_class(:UndoableCollisionAvoidingCountingClass, Symbol[], [UndoableClass, AvoidCollisionClass, CountingClass])

const NamedThing = _new_class(:NamedThing, [:name], [Object])

const AnotherPerson = _new_class(:AnotherPerson, [:age, :friend], [NamedThing], UndoableCollisionAvoidingCountingClass)

@defmethod print_object(p::AnotherPerson, io) =
    print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]")

# ---- Tests Start ----

@testset "2.1 Classes" begin
    # -- Test Top -- 
    @test Top.name === :Top

    @test Top.cpl == [Top]
    @test Top.direct_superclasses == []

    @test Top.slots == []
    @test Top.direct_slots == []

    @test Top.defaulted == Dict{Symbol,Any}()

    @test class_of(Top) === Class
    @test get_print_object_output(Top) == "<Class Top>"

    # -- Test Object --
    @test Object.name === :Object

    @test Object.cpl == [Object, Top]
    @test Object.direct_superclasses == [Top]

    @test Object.slots == []
    @test Object.direct_slots == []

    @test Object.defaulted == Dict{Symbol,Any}()

    @test class_of(Object) === Class
    @test get_print_object_output(Object) == "<Class Object>"

    # -- Test Class --
    @test Class.name === :Class

    @test Class.cpl == [Class, Object, Top]
    @test Class.direct_superclasses == [Object]

    @test Class.slots == collect(fieldnames(MClass))
    @test Class.direct_slots == collect(fieldnames(MClass))

    @test Class.defaulted == Dict{Symbol,Any}()

    @test class_of(Class) === Class
    @test get_print_object_output(Class) == "<Class Class>"

    # -- Test MultiMethod --
    @test MultiMethod.name === :MultiMethod

    @test MultiMethod.cpl == [MultiMethod, Object, Top]
    @test MultiMethod.direct_superclasses == [Object]

    @test MultiMethod.slots == collect(fieldnames(MMultiMethod))
    @test MultiMethod.direct_slots == collect(fieldnames(MMultiMethod))

    @test MultiMethod.defaulted == Dict{Symbol,Any}()

    @test class_of(MultiMethod) === Class
    @test get_print_object_output(MultiMethod) == "<Class MultiMethod>"

    # -- Test GenericFunction --
    @test GenericFunction.name === :GenericFunction

    @test GenericFunction.cpl == [GenericFunction, Object, Top]
    @test GenericFunction.direct_superclasses == [Object]

    @test GenericFunction.slots == collect(fieldnames(MGenericFunction))
    @test GenericFunction.direct_slots == collect(fieldnames(MGenericFunction))

    @test GenericFunction.defaulted == Dict{Symbol,Any}()

    @test class_of(GenericFunction) === Class
    @test get_print_object_output(GenericFunction) == "<Class GenericFunction>"

    # -- Test BuiltInClass --
    @test BuiltInClass.name === :BuiltInClass

    @test BuiltInClass.cpl == [BuiltInClass, Class, Object, Top]
    @test BuiltInClass.direct_superclasses == [Class]

    @test BuiltInClass.slots == collect(fieldnames(MClass))
    @test BuiltInClass.direct_slots == []

    @test BuiltInClass.defaulted == Dict{Symbol,Any}()

    @test class_of(BuiltInClass) === Class
    @test get_print_object_output(BuiltInClass) == "<Class BuiltInClass>"

    # -- Test _Int64 --
    @test _Int64.name === :_Int64

    @test _Int64.cpl == [_Int64, Top]
    @test _Int64.direct_superclasses == [Top]

    @test _Int64.slots == []
    @test _Int64.direct_slots == []

    @test _Int64.defaulted == Dict{Symbol,Any}()

    @test class_of(_Int64) === BuiltInClass
    @test get_print_object_output(_Int64) == "<BuiltInClass _Int64>"

    # -- Test _String -
    @test _String.name === :_String

    @test _String.cpl == [_String, Top]
    @test _String.direct_superclasses == [Top]

    @test _String.slots == []
    @test _String.direct_slots == []

    @test _String.defaulted == Dict{Symbol,Any}()

    @test class_of(_String) === BuiltInClass
    @test get_print_object_output(_String) == "<BuiltInClass _String>"
end

@testset "2.2 Objects" begin
    # -- Test new with Too Many Arguments --
    @test_throws ErrorException new(ComplexNumber, real=1, imag=2, wrong=3)

    # -- Test new with Too Few Arguments --
    @test_throws ErrorException new(ComplexNumber, real=1)

    # -- Test new with Invalid Slot Name --
    @test_throws ErrorException new(ComplexNumber, real=1, wrong=3)

    # -- Test new with Missing Not Defaulted Slot --
    ComplexNumberDefaulted = _new_class(:ComplexNumberDefaulted, Symbol[], [ComplexNumber])
    ComplexNumberDefaulted.defaulted = Dict{Symbol,Any}(:real => 0)

    @test new(ComplexNumberDefaulted, imag=2).real === 0
    @test_throws ErrorException new(ComplexNumberDefaulted, real=1)
end

@testset "2.3 Slot Access" begin
    # -- Test getproperty --
    @test getproperty(c1, :real) === 1
    @test c1.real === 1

    @test getproperty(c1, :imag) === 2
    @test c1.imag === 2

    @test_throws ErrorException c1.wrong

    # -- Test setproperty! --
    c1_copy = c1
    @test setproperty!(c1_copy, :imag, -1) === -1

    c1_copy.imag += 3
    @test c1.imag === 2

    @test_throws ErrorException c1_copy.wrong = 3
end

@testset "2.4 Generic Functions and Methods" begin
    # -- Test add --
    @test add(1, 2) === 3
    @test add("Hello ", "World!") === "Hello World!"
end

@testset "2.5 Pre-defined Generic Functions and Methods" begin
    # -- Test print_object --
    @test class_of(print_object) === GenericFunction

    @test length(print_object.methods) != 0
    @test print_object.params == [:obj, :io]
    @test print_object.name === :print_object

    @test get_print_object_output(c1) == "1+2i"
end

@testset "2.6 MetaObjects" begin
    # -- Test class_of --
    @test class_of(Top) === Class
    @test class_of(Object) === Class
    @test class_of(Class) === Class
    @test class_of(MultiMethod) === Class
    @test class_of(GenericFunction) === Class
    @test class_of(BuiltInClass) === Class

    @test class_of(_Int64) === BuiltInClass
    @test class_of(_String) === BuiltInClass

    @test class_of(ComplexNumber) === Class

    @test class_of(print_object) === GenericFunction
    @test class_of(print_object.methods[1]) === MultiMethod

    @test class_of(c1) === ComplexNumber

    @test class_of(1) === _Int64
    @test class_of("Jos") === _String

    # -- Test ComplexNumber --
    @test ComplexNumber.name === :ComplexNumber

    @test ComplexNumber.cpl == [ComplexNumber, Object, Top]
    @test ComplexNumber.direct_superclasses == [Object]

    @test ComplexNumber.direct_slots == [:real, :imag]
    @test ComplexNumber.slots == [:real, :imag]

    @test ComplexNumber.defaulted == Dict{Symbol,Any}()

    # -- Test add Generic Function --    
    @test add.name === :add
    @test add.params == [:x, :y]

    @test length(add.methods) != 0
    @test add.methods[1].generic_function === add

    @test class_of(add) === GenericFunction
    @test class_of(add.methods[1]) === MultiMethod

    @test get_print_object_output(add) == "<GenericFunction add with 3 methods>"
    @test get_print_object_output(add.methods[1]) == "<MultiMethod add(_Int64, _Int64)>"
end

@testset "2.7 Class Options" begin
    # TODO: @defclass with options
    # @defclass(ComplexNumber, [], [real, imag])
    @test get_print_object_output(ComplexNumber) == "<Class ComplexNumber>"
end

@testset "2.8 Readers and Writers" begin
    # TODO: @defclass using @defmethod for getters and setters
end

@testset "2.9 Generic Function Calls" begin
    # -- Test no_applicable_method --
    @test_throws ErrorException add(1, "Hello")
    @test_throws ErrorException add("Hello", 1)

    # -- Test call_next_method --
    @defmethod foo(x) = "Top"

    @defmethod foo(x::_Int64) = ["_Int64", call_next_method()]

    @test foo(1) == ["_Int64", "Top"]
end

@testset "2.10 Multiple Dispatch" begin
    # -- Test with Shapes and Devices Example --
    expected = [["Drawing a Line on a Printer",
            "Drawing a Circle on a Printer"],
        ["Drawing a Line on a Screen",
            "Drawing a Circle on a Screen"]]

    devices = [new(Printer, color=:black), new(Screen, color=:black)]

    shapes = [new(Line, from=1, to=2), new(Circle, center=1, radius=2)]

    for (device, expect) in zip(devices, expected)
        for (shape, exp) in zip(shapes, expect)
            @test draw(shape, device) == exp
        end
    end
end

@testset "2.11 Multiple Inheritance" begin
    # -- Test Mixins with extension of the Shapes and Devices Example --
    expected = [[:black, "Drawing a Line on a Printer", :black],
        [:red, "Drawing a Circle on a Printer", :black],
        [:blue, "Drawing a Line on a Printer", :black]]

    printer = new(Printer, color=:black)

    shapes = [new(ColoredLine, from=1, to=2, color=:black),
        new(ColoredCircle, center=1, radius=2, color=:red),
        new(ColoredLine, from=1, to=2, color=:blue)]

    for (shape, expect) in zip(shapes, expected)
        @test draw(shape, printer) == expect
    end
end

@testset "2.12 Class Hierarchy" begin
    # -- Test that Class Hierarchy is finite --
    @test ColoredCircle.direct_superclasses == [ColorMixin, Circle]

    @test ColorMixin.direct_superclasses == [Object]

    @test Object.direct_superclasses == [Top]

    @test Top.direct_superclasses == []
end

@testset "2.13 Class Precedence List" begin
    # -- Test Class Precedence List --
    A = _new_class(:A, Symbol[], MClass[Object])
    B = _new_class(:B, Symbol[], MClass[Object])
    C = _new_class(:C, Symbol[], MClass[Object])
    D = _new_class(:D, Symbol[], MClass[A, B])
    E = _new_class(:E, Symbol[], MClass[A, C])
    F = _new_class(:F, Symbol[], MClass[D, E])

    @test compute_cpl(F) == [F, D, E, A, B, C, Object, Top]
end

@testset "2.14 Built-In Classes" begin
    # -- Test Built-In Classes --
    @test class_of(1) == _Int64

    @test class_of("a") == _String

    @test class_of(_Int64) == BuiltInClass

    @test class_of(_String) == BuiltInClass

    @test add(1, 2) == 3

    @test add("Hello ", "World!") == "Hello World!"
end

@testset "2.15 Introspection" begin
    @test class_name(Circle) === :Circle
    @test class_direct_slots(Circle) == [:center, :radius]

    @test class_slots(ColoredCircle) == [:color, :center, :radius]
    @test class_direct_slots(ColoredCircle) == []

    @test class_direct_superclasses(ColoredCircle) == [ColorMixin, Circle]
    @test class_cpl(ColoredCircle) == [ColoredCircle, ColorMixin, Circle, Object, Shape, Top]

    @test length(generic_methods(draw)) == 5

    @test length(method_specializers(generic_methods(draw)[1])) == 2
end

@testset "2.16.1 Class Instantiation Protocol" begin
    # -- Test CIP with Counting Class --
    foo1 = new(CountingFoo)
    foo2 = new(CountingFoo)
    foo3 = new(CountingFoo)
    @test CountingFoo.counter == 3

    bar1 = new(CountingBar)
    bar2 = new(CountingBar)
    @test CountingBar.counter == 2
end

@testset "2.16.2 The Compute Slots Protocol" begin
    # -- Test CSP with Collision AvoidCollisionClass --
    @test class_slots(FooBar) == [:a, :d, :a, :b, :b, :c]

    @test_throws ErrorException _new_class(:CAFooBar, [:a, :d], [Foo, Bar], AvoidCollisionClass)
end

@testset "2.16.3 Slot Access Protocol" begin
    # -- Test SAP with Slot Access Class --
    p0 = new(Person, name="John", age=21, friend=missing)
    p1 = new(Person, name="Paul", age=23, friend=missing)

    # Paul has a friend name John    
    p1.friend = p0
    state0 = current_state()

    # 32 years later, John changed his name to 'Louis' and got a friend
    p0.age = 53
    p1.age = 55
    p0.name = "Louis"
    p0.friend = new(Person, name="Mary", age=19, friend=missing)
    state1 = current_state()

    # 15 years later, John (hum, I mean 'Louis') died
    p1.age = 70
    p1.friend = missing
    state2 = current_state()

    # Let's go back in time
    restore_state(state1)
    @test p0.age == 53
    @test p1.age == 55
    @test p0.name == "Louis"
    @test p0.friend.name == "Mary"

    # And even earlier
    restore_state(state0)
    @test p0.age == 21
    @test p1.age == 23
    @test p0.name == "John"
    @test p1.name == "Paul"
    @test p1.friend.name == "John"
end

@testset "2.16.4 Class Precedence List Protocol" begin
    # -- Test CPLP with Flavors Example --
    A = _new_class(:A, Symbol[], [Object], FlavorsClass)
    B = _new_class(:B, Symbol[], [Object], FlavorsClass)
    C = _new_class(:C, Symbol[], [Object], FlavorsClass)
    D = _new_class(:D, Symbol[], [A, B], FlavorsClass)
    E = _new_class(:E, Symbol[], [A, C], FlavorsClass)
    F = _new_class(:F, Symbol[], [D, E], FlavorsClass)

    @test compute_cpl(F) == [F, D, A, B, E, C, Object, Top]
end

@testset "2.17 Multiple Meta-Class Inheritance" begin
    # -- Test MMCI --
    @test_throws ErrorException AnotherNamedThing =
        _new_class(:AnotherNamedThing, [:name], [NamedThing], UndoableCollisionAvoidingCountingClass)

    p0 = new(AnotherPerson, name="John", age=21, friend=missing)
    p1 = new(AnotherPerson, name="Paul", age=23, friend=missing)

    # Paul has a friend name John    
    p1.friend = p0
    state0 = current_state()

    # 32 years later, John changed his name to 'Louis' and got a friend
    p0.age = 53
    p1.age = 55
    p0.name = "Louis"
    p0.friend = new(AnotherPerson, name="Mary", age=19, friend=missing)
    state1 = current_state()

    # 15 years later, John (hum, I mean 'Louis') died
    p1.age = 70
    p1.friend = missing
    state2 = current_state()

    # Let's go back in time
    restore_state(state1)
    @test p0.age == 53
    @test p1.age == 55
    @test p0.name == "Louis"
    @test p0.friend.name == "Mary"

    # And even earlier
    restore_state(state0)
    @test p0.age == 21
    @test p1.age == 23
    @test p0.name == "John"
    @test p1.name == "Paul"
    @test p1.friend.name == "John"

    @test AnotherPerson.counter == 3
end