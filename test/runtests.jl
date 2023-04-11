using Test, Jos

# ---- Helper Functions ----

function get_print_object_output(c)
    io = IOBuffer()
    Jos.print_object(c, io)
    return String(take!(io))
end

# ---- Base Generic Functions ----

add = Jos.MGenericFunction(:add, [:x, :y], [])

draw = Jos.MGenericFunction(:draw, [:shape, :device], [])

# ---- Base Classes ----

Jos._add_method(add, [Jos._Int64, Jos._Int64], (call_next_method, x, y) -> x + y)

Jos._add_method(add, [Jos._String, Jos._String], (call_next_method, x, y) -> x * y)

# ---- Complex Numbers Example ----

const ComplexNumber = Jos._new_class(:ComplexNumber, [:real, :imag], [Jos.Object])

const c1 = Jos.new(ComplexNumber, real=1, imag=2)

const c2 = Jos.new(ComplexNumber, real=3, imag=4)

Jos._add_method(add, [ComplexNumber, ComplexNumber], (call_next_method, x, y) -> x + y)

Jos._add_method(Jos.print_object, [ComplexNumber], (call_next_method, c, io) -> print(io, "$(c.real)$(c.imag < 0 ? "-" : "+")$(abs(c.imag))i"))

# ---- Shapes and Devices Example ----

const Shape = Jos._new_class(:Shape, Symbol[], [Jos.Object])

const Line = Jos._new_class(:Line, [:from, :to], [Shape])

const Circle = Jos._new_class(:Circle, [:center, :radius], [Shape])

const Device = Jos._new_class(:Device, Symbol[:color], [Jos.Object])

const Screen = Jos._new_class(:Screen, Symbol[], [Device])

const Printer = Jos._new_class(:Printer, Symbol[], [Device])

Jos._add_method(draw, [Line, Screen], (call_next_method, shape, device) -> "Drawing a Line on a Screen")

Jos._add_method(draw, [Circle, Screen], (call_next_method, shape, device) -> "Drawing a Circle on a Screen")

Jos._add_method(draw, [Line, Printer], (call_next_method, shape, device) -> "Drawing a Line on a Printer")

Jos._add_method(draw, [Circle, Printer], (call_next_method, shape, device) -> "Drawing a Circle on a Printer")

# ---- Mixins Example ----

const ColorMixin = Jos._new_class(:ColorMixin, [:color], [Jos.Object])

const ColoredLine = Jos._new_class(:ColoredLine, Symbol[], [ColorMixin, Line])

const ColoredCircle = Jos._new_class(:ColoredCircle, Symbol[], [ColorMixin, Circle])

Jos._add_method(draw, [ColorMixin, Device], (call_next_method, shape, device) ->
    let previous_color = device.color
        device.color = shape.color
        action = call_next_method()
        device.color = previous_color
        [shape.color, action, previous_color]
    end)

# ---- Counting Class Example ----

const CountingClass = Jos._new_class(:CountingClass, [:counter], [Jos.Class])

CountingClass.defaulted = Dict{Symbol,Any}(:counter => 0)

Jos._add_method(Jos.allocate_instance, [CountingClass], (call_next_method, class) -> begin
    class.counter += 1
    call_next_method()
end
)

const CountingFoo = Jos._new_class(:CountingFoo, Symbol[], [Jos.Object], CountingClass)

const CountingBar = Jos._new_class(:CountingBar, Symbol[], [Jos.Object], CountingClass)

# ---- Collision Avoiding Class Example ----

const AvoidCollisionClass = Jos._new_class(:AvoidCollisionClass, Symbol[], [Jos.Class])

Jos._add_method(Jos.compute_slots, [AvoidCollisionClass],
    (call_next_method, class) ->
        let slots = call_next_method()
            duplicates = symdiff(slots, unique(slots))
            isempty(duplicates) ?
            slots :
            error("Multiple occurrences of slots: $(join(map(string, duplicates), ", "))")
        end
)

const Foo = Jos._new_class(:Foo, [:a, :b], [Jos.Object])

const Bar = Jos._new_class(:Bar, [:b, :c], [Jos.Object])

const FooBar = Jos._new_class(:FooBar, [:a, :d], [Foo, Bar])

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

const UndoableClass = Jos._new_class(:UndoableClass, Symbol[], [Jos.Class])

Jos._add_method(Jos.compute_getter_and_setter, [UndoableClass],
    (call_next_method, cls, slot, idx) ->
        let (getter, setter) = call_next_method()
            (getter,
                (o, v) -> begin
                    if save_previous_value
                        store_previous(o, slot, getter(o))
                    end
                    setter(o, v)
                end)
        end)

const Person = Jos._new_class(:Person, [:name, :age, :friend], [Jos.Object], UndoableClass)

Jos._add_method(Jos.print_object, [Person],
    (call_next_method, p, io) -> print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]"))

# ---- Flavors Example ----

const FlavorsClass = Jos._new_class(:FlavorsClass, Symbol[], [Jos.Class])

Jos._add_method(Jos.compute_cpl, [FlavorsClass], (call_next_method, cls) ->
    let depth_first_cpl(class) = [class, foldl(vcat, map(depth_first_cpl, Jos.class_direct_superclasses(class)), init=[])...],
        base_cpl = [Jos.Object, Jos.Top]

        vcat(unique(filter(!in(base_cpl), depth_first_cpl(cls))), base_cpl)
    end)

# ---- Multiple Meta-Class Inheritance ----

const UndoableCollisionAvoidingCountingClass = 
    Jos._new_class(:UndoableCollisionAvoidingCountingClass, Symbol[], [UndoableClass, AvoidCollisionClass, CountingClass])

const NamedThing = Jos._new_class(:NamedThing, [:name], [Jos.Object])

const AnotherPerson = Jos._new_class(:AnotherPerson, [:age, :friend], [NamedThing], UndoableCollisionAvoidingCountingClass)

Jos._add_method(Jos.print_object, [AnotherPerson],
    (call_next_method, p, io) -> print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]"))

# ---- Tests Start ----

@testset "2.1 Classes" begin
    # -- Test Jos.Top -- 
    @test Jos.Top.name === :Top

    @test Jos.Top.cpl == [Jos.Top]
    @test Jos.Top.direct_superclasses == []

    @test Jos.Top.slots == []
    @test Jos.Top.direct_slots == []

    @test Jos.Top.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos.Top) === Jos.Class
    @test get_print_object_output(Jos.Top) == "<Class Top>"

    # -- Test Jos.Object --
    @test Jos.Object.name === :Object

    @test Jos.Object.cpl == [Jos.Object, Jos.Top]
    @test Jos.Object.direct_superclasses == [Jos.Top]

    @test Jos.Object.slots == []
    @test Jos.Object.direct_slots == []

    @test Jos.Object.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos.Object) === Jos.Class
    @test get_print_object_output(Jos.Object) == "<Class Object>"

    # -- Test Jos.Class --
    @test Jos.Class.name === :Class

    @test Jos.Class.cpl == [Jos.Class, Jos.Object, Jos.Top]
    @test Jos.Class.direct_superclasses == [Jos.Object]

    @test Jos.Class.slots == collect(fieldnames(Jos.MClass))
    @test Jos.Class.direct_slots == collect(fieldnames(Jos.MClass))

    @test Jos.Class.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos.Class) === Jos.Class
    @test get_print_object_output(Jos.Class) == "<Class Class>"

    # -- Test Jos.MultiMethod --
    @test Jos.MultiMethod.name === :MultiMethod

    @test Jos.MultiMethod.cpl == [Jos.MultiMethod, Jos.Object, Jos.Top]
    @test Jos.MultiMethod.direct_superclasses == [Jos.Object]

    @test Jos.MultiMethod.slots == collect(fieldnames(Jos.MMultiMethod))
    @test Jos.MultiMethod.direct_slots == collect(fieldnames(Jos.MMultiMethod))

    @test Jos.MultiMethod.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos.MultiMethod) === Jos.Class
    @test get_print_object_output(Jos.MultiMethod) == "<Class MultiMethod>"

    # -- Test Jos.GenericFunction --
    @test Jos.GenericFunction.name === :GenericFunction

    @test Jos.GenericFunction.cpl == [Jos.GenericFunction, Jos.Object, Jos.Top]
    @test Jos.GenericFunction.direct_superclasses == [Jos.Object]

    @test Jos.GenericFunction.slots == collect(fieldnames(Jos.MGenericFunction))
    @test Jos.GenericFunction.direct_slots == collect(fieldnames(Jos.MGenericFunction))

    @test Jos.GenericFunction.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos.GenericFunction) === Jos.Class
    @test get_print_object_output(Jos.GenericFunction) == "<Class GenericFunction>"

    # -- Test Jos.BuiltInClass --
    @test Jos.BuiltInClass.name === :BuiltInClass

    @test Jos.BuiltInClass.cpl == [Jos.BuiltInClass, Jos.Class, Jos.Object, Jos.Top]
    @test Jos.BuiltInClass.direct_superclasses == [Jos.Class]

    @test Jos.BuiltInClass.slots == collect(fieldnames(Jos.MClass))
    @test Jos.BuiltInClass.direct_slots == []

    @test Jos.BuiltInClass.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos.BuiltInClass) === Jos.Class
    @test get_print_object_output(Jos.BuiltInClass) == "<Class BuiltInClass>"

    # -- Test Jos._Int64 --
    @test Jos._Int64.name === :_Int64

    @test Jos._Int64.cpl == [Jos._Int64, Jos.Top]
    @test Jos._Int64.direct_superclasses == [Jos.Top]

    @test Jos._Int64.slots == []
    @test Jos._Int64.direct_slots == []

    @test Jos._Int64.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos._Int64) === Jos.BuiltInClass
    @test get_print_object_output(Jos._Int64) == "<BuiltInClass _Int64>"

    # -- Test Jos._String -
    @test Jos._String.name === :_String

    @test Jos._String.cpl == [Jos._String, Jos.Top]
    @test Jos._String.direct_superclasses == [Jos.Top]

    @test Jos._String.slots == []
    @test Jos._String.direct_slots == []

    @test Jos._String.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos._String) === Jos.BuiltInClass
    @test get_print_object_output(Jos._String) == "<BuiltInClass _String>"
end

@testset "2.2 Objects" begin
    # -- Test Jos.new with Too Many Arguments --
    @test_throws ErrorException Jos.new(ComplexNumber, real=1, imag=2, wrong=3)

    # -- Test Jos.new with Too Few Arguments --
    @test_throws ErrorException Jos.new(ComplexNumber, real=1)

    # -- Test Jos.new with Invalid Slot Name --
    @test_throws ErrorException Jos.new(ComplexNumber, real=1, wrong=3)

    # -- Test Jos.new with Missing Not Defaulted Slot --
    ComplexNumberDefaulted = Jos._new_class(:ComplexNumberDefaulted, Symbol[], [ComplexNumber])
    ComplexNumberDefaulted.defaulted = Dict{Symbol,Any}(:real => 0)

    @test Jos.new(ComplexNumberDefaulted, imag=2).real === 0
    @test_throws ErrorException Jos.new(ComplexNumberDefaulted, real=1)
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
    # -- Test Jos.add --
    @test add(1, 2) === 3
    @test add("Hello ", "World!") === "Hello World!"
end

@testset "2.5 Pre-defined Generic Functions and Methods" begin
    # -- Test Jos.print_object --
    @test Jos.class_of(Jos.print_object) === Jos.GenericFunction

    @test length(Jos.print_object.methods) != 0
    @test Jos.print_object.params == [:obj, :io]
    @test Jos.print_object.name === :print_object

    @test get_print_object_output(c1) == "1+2i"
end

@testset "2.6 MetaObjects" begin
    # -- Test Jos.class_of --
    @test Jos.class_of(Jos.Top) === Jos.Class
    @test Jos.class_of(Jos.Object) === Jos.Class
    @test Jos.class_of(Jos.Class) === Jos.Class
    @test Jos.class_of(Jos.MultiMethod) === Jos.Class
    @test Jos.class_of(Jos.GenericFunction) === Jos.Class
    @test Jos.class_of(Jos.BuiltInClass) === Jos.Class

    @test Jos.class_of(Jos._Int64) === Jos.BuiltInClass
    @test Jos.class_of(Jos._String) === Jos.BuiltInClass

    @test Jos.class_of(ComplexNumber) === Jos.Class

    @test Jos.class_of(Jos.print_object) === Jos.GenericFunction
    @test Jos.class_of(Jos.print_object.methods[1]) === Jos.MultiMethod

    @test Jos.class_of(c1) === ComplexNumber

    @test Jos.class_of(1) === Jos._Int64
    @test Jos.class_of("Jos") === Jos._String

    # -- Test ComplexNumber --
    @test ComplexNumber.name === :ComplexNumber

    @test ComplexNumber.cpl == [ComplexNumber, Jos.Object, Jos.Top]
    @test ComplexNumber.direct_superclasses == [Jos.Object]

    @test ComplexNumber.direct_slots == [:real, :imag]
    @test ComplexNumber.slots == [:real, :imag]

    @test ComplexNumber.defaulted == Dict{Symbol,Any}()

    # -- Test add Generic Function --    
    @test add.name === :add
    @test add.params == [:x, :y]

    @test length(add.methods) != 0
    @test add.methods[1].generic_function === add

    @test Jos.class_of(add) === Jos.GenericFunction
    @test Jos.class_of(add.methods[1]) === Jos.MultiMethod

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
    Jos.@defgeneric foo(x)

    Jos._add_method(foo, Jos.MClass[Jos.Top],
        (call_next_method, x) ->
            "Top")

    Jos._add_method(foo, Jos.MClass[Jos._Int64],
        (call_next_method, x) ->
            ["_Int64", call_next_method()])

    @test foo(1) == ["_Int64", "Top"]
end

@testset "2.10 Multiple Dispatch" begin
    # -- Test with Shapes and Devices Example --
    expected = [["Drawing a Line on a Printer",
            "Drawing a Circle on a Printer"],
        ["Drawing a Line on a Screen",
            "Drawing a Circle on a Screen"]]

    devices = [Jos.new(Printer, color=:black), Jos.new(Screen, color=:black)]

    shapes = [Jos.new(Line, from=1, to=2), Jos.new(Circle, center=1, radius=2)]

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

    printer = Jos.new(Printer, color=:black)

    shapes = [Jos.new(ColoredLine, from=1, to=2, color=:black),
        Jos.new(ColoredCircle, center=1, radius=2, color=:red),
        Jos.new(ColoredLine, from=1, to=2, color=:blue)]

    for (shape, expect) in zip(shapes, expected)
        @test draw(shape, printer) == expect
    end
end

@testset "2.12 Class Hierarchy" begin
    # -- Test that Class Hierarchy is finite --
    @test ColoredCircle.direct_superclasses == [ColorMixin, Circle]

    @test ColorMixin.direct_superclasses == [Jos.Object]

    @test Jos.Object.direct_superclasses == [Jos.Top]

    @test Jos.Top.direct_superclasses == []
end

@testset "2.13 Class Precedence List" begin
    # -- Test Class Precedence List --
    A = Jos._new_class(:A, Symbol[], Jos.MClass[Jos.Object])
    B = Jos._new_class(:B, Symbol[], Jos.MClass[Jos.Object])
    C = Jos._new_class(:C, Symbol[], Jos.MClass[Jos.Object])
    D = Jos._new_class(:D, Symbol[], Jos.MClass[A, B])
    E = Jos._new_class(:E, Symbol[], Jos.MClass[A, C])
    F = Jos._new_class(:F, Symbol[], Jos.MClass[D, E])

    @test Jos._compute_cpl(F) == [F, D, E, A, B, C, Jos.Object, Jos.Top]
end

@testset "2.14 Built-In Classes" begin
    # -- Test Built-In Classes --
    @test Jos.class_of(1) == Jos._Int64

    @test Jos.class_of("a") == Jos._String

    @test Jos.class_of(Jos._Int64) == Jos.BuiltInClass

    @test Jos.class_of(Jos._String) == Jos.BuiltInClass

    @test add(1, 2) == 3

    @test add("Hello ", "World!") == "Hello World!"
end

@testset "2.15 Introspection" begin
    @test Jos.class_name(Circle) === :Circle
    @test Jos.class_direct_slots(Circle) == [:center, :radius]

    @test Jos.class_slots(ColoredCircle) == [:color, :center, :radius]
    @test Jos.class_direct_slots(ColoredCircle) == []

    @test Jos.class_direct_superclasses(ColoredCircle) == [ColorMixin, Circle]
    @test Jos.class_cpl(ColoredCircle) == [ColoredCircle, ColorMixin, Circle, Jos.Object, Shape, Jos.Top]

    @test length(Jos.generic_methods(draw)) == 5

    @test length(Jos.method_specializers(Jos.generic_methods(draw)[1])) == 2
end

@testset "2.16.1 Class Instantiation Protocol" begin
    # -- Test CIP with Counting Class --
    foo1 = Jos.new(CountingFoo)
    foo2 = Jos.new(CountingFoo)
    foo3 = Jos.new(CountingFoo)
    @test CountingFoo.counter == 3

    bar1 = Jos.new(CountingBar)
    bar2 = Jos.new(CountingBar)
    @test CountingBar.counter == 2
end

@testset "2.16.2 The Compute Slots Protocol" begin
    # -- Test CSP with Collision AvoidCollisionClass --
    @test Jos.class_slots(FooBar) == [:a, :d, :a, :b, :b, :c]

    @test_throws ErrorException Jos._new_class(:CAFooBar, [:a, :d], [Foo, Bar], AvoidCollisionClass)
end

@testset "2.16.3 Slot Access Protocol" begin
    # -- Test SAP with Slot Access Class --
    p0 = Jos.new(Person, name="John", age=21, friend=missing)
    p1 = Jos.new(Person, name="Paul", age=23, friend=missing)

    # Paul has a friend name John    
    p1.friend = p0
    state0 = current_state()

    # 32 years later, John changed his name to 'Louis' and got a friend
    p0.age = 53
    p1.age = 55
    p0.name = "Louis"
    p0.friend = Jos.new(Person, name="Mary", age=19, friend=missing)
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
    A = Jos._new_class(:A, Symbol[], [Jos.Object], FlavorsClass)
    B = Jos._new_class(:B, Symbol[], [Jos.Object], FlavorsClass)
    C = Jos._new_class(:C, Symbol[], [Jos.Object], FlavorsClass)
    D = Jos._new_class(:D, Symbol[], [A, B], FlavorsClass)
    E = Jos._new_class(:E, Symbol[], [A, C], FlavorsClass)
    F = Jos._new_class(:F, Symbol[], [D, E], FlavorsClass)

    @test Jos.compute_cpl(F) == [F, D, A, B, E, C, Jos.Object, Jos.Top]
end

@testset "2.17 Multiple Meta-Class Inheritance" begin
    # -- Test MMCI --
    @test_throws ErrorException AnotherNamedThing = 
        Jos._new_class(:AnotherNamedThing, [:name], [NamedThing], UndoableCollisionAvoidingCountingClass)

    p0 = Jos.new(AnotherPerson, name="John", age=21, friend=missing)
    p1 = Jos.new(AnotherPerson, name="Paul", age=23, friend=missing)

    # Paul has a friend name John    
    p1.friend = p0
    state0 = current_state()

    # 32 years later, John changed his name to 'Louis' and got a friend
    p0.age = 53
    p1.age = 55
    p0.name = "Louis"
    p0.friend = Jos.new(AnotherPerson, name="Mary", age=19, friend=missing)
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

@testset "2.18 Extensions" begin
end