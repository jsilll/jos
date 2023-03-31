using Test, Jos

# ---- Helper Functions ----

function get_print_object_output(c)
    io = IOBuffer()
    Jos.print_object(c, io)
    return String(take!(io))
end

# ---- Complex Numbers Example ----

const ComplexNumber = Jos._new_default_class(:ComplexNumber, [:real, :imag], [Jos.Object])

const c1 = Jos.new(ComplexNumber, real=1, imag=2)
const c2 = Jos.new(ComplexNumber, real=3, imag=4)

Jos.@defgeneric add(x, y)

Jos._add_method(add, [ComplexNumber, ComplexNumber],
    (call_next_method, a, b) -> Jos.new(ComplexNumber, real=a.real + b.real, imag=a.imag + b.imag))

Jos._add_method(Jos.print_object, [ComplexNumber, Jos.Top],
    (call_next_method, c, io) -> print(io, "$(c.real)$(c.imag < 0 ? "-" : "+")$(abs(c.imag))i"))

# ---- Shapes and Devices Example ----

const Shape = Jos._new_default_class(:Shape, Symbol[], [Jos.Object])

const Line = Jos._new_default_class(:Line, [:from, :to], [Shape])
const Circle = Jos._new_default_class(:Circle, [:center, :radius], [Shape])

const Device = Jos._new_default_class(:Device, Symbol[:color], [Jos.Object])

const Screen = Jos._new_default_class(:Screen, Symbol[], [Device])
const Printer = Jos._new_default_class(:Printer, Symbol[], [Device])

Jos.@defgeneric draw(shape, device)

Jos._add_method(draw, [Line, Screen],
    (call_next_method::Function, line, screen) -> "Drawing a line on a screen")

Jos._add_method(draw, [Circle, Screen],
    (call_next_method::Function, circle, screen) -> "Drawing a circle on a screen")

Jos._add_method(draw, [Line, Printer],
    (call_next_method::Function, line, printer) -> "Drawing a line on a printer")

Jos._add_method(draw, [Circle, Printer],
    (call_next_method::Function, circle, printer) -> "Drawing a circle on a printer")

# ---- Mixins Example ----

const ColorMixin = Jos._new_default_class(:ColorMixin, [:color], [Jos.Object])

const ColoredLine = Jos._new_default_class(:ColoredLine, Symbol[], [ColorMixin, Line])
const ColoredCircle = Jos._new_default_class(:ColoredCircle, Symbol[], [ColorMixin, Circle])

Jos._add_method(draw, [ColorMixin, Device],
    (call_next_method::Function, circle, device) ->
        let previous_color = device.color
            device.color = circle.color
            action = call_next_method()
            device.color = previous_color
            ["$(circle.color)", action, "$(previous_color)"]
        end
)

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

    @test Jos._Int64.cpl == [Jos._Int64, Jos.Object, Jos.Top]
    @test Jos._Int64.direct_superclasses == [Jos.Object]

    @test Jos._Int64.slots == []
    @test Jos._Int64.direct_slots == []

    @test Jos._Int64.defaulted == Dict{Symbol,Any}()

    @test Jos.class_of(Jos._Int64) === Jos.BuiltInClass
    @test get_print_object_output(Jos._Int64) == "<BuiltInClass _Int64>"

    # -- Test Jos._String -
    @test Jos._String.name === :_String

    @test Jos._String.cpl == [Jos._String, Jos.Object, Jos.Top]
    @test Jos._String.direct_superclasses == [Jos.Object]

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
    ComplexNumberDefaulted = Jos._new_default_class(:ComplexNumberDefaulted, Symbol[], [ComplexNumber])
    ComplexNumberDefaulted.defaulted = Dict(:real => 0)
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
    # TODO: @defgeneric

    #@defgeneric reflect_object(obj)
    #@defgeneric add(a, b)
    #@defgeneric add(a, b)

    # TODO: @defmethod

    #@defmethod reflect_object(obj::_Int64) = "$(obj) is an _Int64"
    #@defmethod reflect_object(obj::_String) = "$(obj) is a _String"
    #@defmethod add(a::_Int64, b::_Int64) = a + b
    #@defmethod add(a::_Int64, b::_Int64) = a + b
    #@defmethod add(a::_String, b::_String) = a * b
    
    # Calling some methods
    #println("\nResults:")
    #println("For reflect_object(1): ", reflect_object(1))
    #println("For reflect_object('Hello!'): ", reflect_object("Hello"))

    #add_int = add(2,3)
    #println("For add(2, 3): ", add_int, " [Value: ", add_int, "]")
    #add_string = add("Ju", "lia")
    #println("For add('Ju', 'lia'): ", add_string, " [Value: ", add_string, "]")

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

    @test get_print_object_output(add) == "<GenericFunction add with 1 method>"
    @test get_print_object_output(add.methods[1]) == "<MultiMethod add(ComplexNumber, ComplexNumber)>"
end

@testset "2.7 Class Options" begin
    # TODO: @defclass with options
    # DUVIDA: meter missing é o mesmo que nao inicializar com nada?
end

@testset "2.8 Readers and Writers" begin
    # TODO: @defclass using @defmethod for getters and setters
end

@testset "2.9 Generic Function Calls" begin
    # -- Test no_applicable_method --
    @test_throws ErrorException add(1, 2)

    # -- Test call_next_method --
    Jos.@defgeneric foo(x)

    Jos._add_method(foo, Jos.MClass[Jos.Top],
        (call_next_method, x) ->
            "Top")

    Jos._add_method(foo, Jos.MClass[Jos.Object],
        (call_next_method, x) ->
            ["Object", call_next_method()])

    Jos._add_method(foo, Jos.MClass[Jos._Int64],
        (call_next_method, x) ->
            ["_Int64", call_next_method()...])

    @test foo(1) == ["_Int64", "Object", "Top"]
end

@testset "2.10 Multiple Dispatch" begin
    # -- Test with Shapes and Devices Example --
    expected = ["Drawing a line on a printer",
        "Drawing a circle on a printer",
        "Drawing a line on a screen",
        "Drawing a circle on a screen"]

    devices = [Jos.new(Printer, color=:black), Jos.new(Screen, color=:black)]

    shapes = [Jos.new(Line, from=1, to=2), Jos.new(Circle, center=1, radius=2)]

    i = 1
    for device in devices
        for shape in shapes
            @test draw(shape, device) == expected[i]
            i += 1
        end
    end
end

@testset "2.11 Multiple Inheritance" begin
    # -- Test Mixins with extension of the Shapes and Devices Example --
    expected = [["black", "Drawing a line on a printer", "black"],
        ["red", "Drawing a circle on a printer", "black"],
        ["blue", "Drawing a line on a printer", "black"]]

    printer = Jos.new(Printer, color=:black)

    shapes = [Jos.new(ColoredLine, from=1, to=2, color=:black),
        Jos.new(ColoredCircle, center=1, radius=2, color=:red),
        Jos.new(ColoredLine, from=1, to=2, color=:blue)]

    i = 1
    for shape in shapes
        @test draw(shape, printer) == expected[i]
        i += 1
    end
end

@testset "2.12 Class Hierarchy" begin
    # -- Test that Class Hierarchy is finite --
    @test ColoredCircle.direct_superclasses == [ColorMixin, Circle]

    @test ColorMixin.direct_superclasses == [Jos.Object]

    @test Jos.Object.direct_superclasses == [Jos.Top]
end

@testset "2.13 Class Precedence List" begin
    # -- Test Class Precedence List --
    A = Jos.MClass(:A, Symbol[], Jos.MClass[])
    B = Jos.MClass(:B, Symbol[], Jos.MClass[])
    C = Jos.MClass(:C, Symbol[], Jos.MClass[])
    D = Jos.MClass(:D, Symbol[], Jos.MClass[A, B])
    E = Jos.MClass(:E, Symbol[], Jos.MClass[A, C])
    F = Jos.MClass(:F, Symbol[], Jos.MClass[D, E])

    @test Jos._compute_cpl(F) == Vector{Jos.MClass}([F, D, E, A, B, C])
end

@testset "2.14 Built-In Classes" begin
    # -- Test Built-In Classes --
    @test Jos.class_of(1) == Jos._Int64

    @test Jos.class_of("a") == Jos._String

    @test Jos.class_of(Jos._Int64) == Jos.BuiltInClass

    @test Jos.class_of(Jos._String) == Jos.BuiltInClass
end

@testset "2.15 Introspection" begin
    @test Jos.class_name(Circle) === :Circle
    @test Jos.class_direct_slots(Circle) == [:center, :radius]

    @test Jos.class_slots(ColoredCircle) == [:color, :center, :radius]
    @test Jos.class_direct_slots(ColoredCircle) == []

    @test Jos.class_cpl(ColoredCircle) == [ColoredCircle, ColorMixin, Circle, Jos.Object, Shape, Jos.Top]
    @test Jos.class_direct_superclasses(ColoredCircle) == [ColorMixin, Circle]

    @test length(Jos.generic_methods(draw)) == 5

    @test length(Jos.method_specializers(Jos.generic_methods(draw)[1])) == 2
end

@testset "2.16.1 Class Instantiation Protocol" begin
    # TODO
    # @defclass(CountingClass, [Class], [counter=0])
    # @defmethod allocate_instance(class::CountingClass) = begin
    #   class.counter += 1
    #   call_next_method()
    # end
    # @defclass(Foo, [], [], metaclass=CountingClass) == <CountingClass Foo>
    # @defclass(Bar, [], [], metaclass=CountingClass) == <CountingClass Bar>
    # new(Foo)
    # new(Foo)
    # new(Bar)
    # Foo.counter == 2
    # Bar.counter == 1
end

@testset "2.16.2 The Compute Slots Protocol" begin
    # TODO
    # @defmethod compute_slots(class::Class) = 
    #  vcat(map(class_direct_slots, class_cpl(class))...)
    # @defclass(Foo, [], [a=1, b=2])
    # @defclass(Bar, [Foo], [b=3, c=4])
    # @defclass(FooBar, [Foo, Bar], [a=5, d=6])
    # class_slots(Bar) == [:a, :d, :a, :b, :b, :c]
    # foobar1 = new(FooBar)
    # foobar1.a == 1
    # foobar1.b == 3
    # foobar1.c == 4
    # foobar1.d == 6

    # Collision Detection metaclass
    # @defclass(AvoidCollisionsClass, [Class], [])
    # @defmethod compute_slots(class::AvoidCollisionsClass) = 
    # let slots = call_next_method(),
    #   duplicates = symdiff(slots, unique(slots))
    #   isempty(duplicates) ? slots :
    #   error("Multiple occurrences of slots: $(join(map(string, duplicates), ", "))")
    # end
end

@testset "2.16.3 Slot Access Protocol" begin
    # TODO: Understand how to implement this
    # test with undoclass example
end

@testset "2.16.4 Class Precedence List Protocol" begin
    # @defclass(FlavorsClass, [Class], [])
    # @defmethod compute_cpl(class::FlavorsClass) = 
    #   let depth_first_cpl(class) =
    #       [class, foldl(vcat, map(depth_first_cpl, class_direct_superclasses(class)), init=[])...],
    #       base_cpl = [Object, Top]
    #       vcat(unique(filter(!in(base_cpl), depth_first_cpl(class))), base_cpl)
    #   end

    # @defclass(A, [], [], metaclass=FlavorsClass)
    # @defclass(B, [], [], metaclass=FlavorsClass)
    # @defclass(C, [], [], metaclass=FlavorsClass)
    # @defclass(D, [A, B], [], metaclass=FlavorsClass)
    # @defclass(E, [A, C], [], metaclass=FlavorsClass)
    # @defclass(F, [D, E], [], metaclass=FlavorsClass)

    # compute_cpl(F) == [F, D, A, B, E, C, Object, Top]
end

@testset "2.17 Multiple Meta-Class Inheritance" begin
    # TODO: undoable, collision-avoiding, counting class example
end

@testset "2.18 Extensions" begin
    # TODO
end