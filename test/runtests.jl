using Test, Jos

# Create a new class
ComplexNumber = Jos.MClass(:ComplexNumber, [:real, :imag], [Jos.Object])

# Create some instances of the new class
c1 = Jos.new(ComplexNumber, real=1, imag=2)
c2 = Jos.new(ComplexNumber, real=3, imag=4)

# Create a new generic function
add = Jos.MGenericFunction(:add, [:x, :y], [])

# Specialize Generic Function for ComplexNumber
push!(add.methods, Jos.MMultiMethod(
    (a, b) -> Jos.new(ComplexNumber, real=a.real + b.real, imag=a.imag + b.imag), add, [ComplexNumber, ComplexNumber]))

# -- Tests Start --

@testset "2.1 Classes" begin
    @test Jos.Top.name === :Top
    @test Jos.Top.direct_slots == []
    @test Jos.Top.direct_superclasses == []
    @test Jos.class_of(Jos.Top) === Jos.Class

    @test Jos.Object.name === :Object
    @test Jos.Object.direct_slots == []
    @test Jos.Object.direct_superclasses == [Jos.Top]
    @test Jos.class_of(Jos.Object) === Jos.Class

    @test Jos.Class.name === :Class
    @test Jos.Class.direct_superclasses == [Jos.Object]
    @test Jos.Class.direct_slots == collect(fieldnames(Jos.MClass))
    @test Jos.class_of(Jos.Class) === Jos.Class

    @test Jos.MultiMethod.name === :MultiMethod
    @test Jos.MultiMethod.direct_superclasses == [Jos.Top]
    @test Jos.MultiMethod.direct_slots == collect(fieldnames(Jos.MMultiMethod))
    @test Jos.class_of(Jos.MultiMethod) === Jos.Class

    @test Jos.GenericFunction.name === :GenericFunction
    @test Jos.GenericFunction.direct_superclasses == [Jos.MultiMethod]
    @test Jos.GenericFunction.direct_slots == collect(fieldnames(Jos.MGenericFunction))
    @test Jos.class_of(Jos.GenericFunction) === Jos.Class

    @test Jos.BuiltInClass.name === :BuiltInClass
    @test Jos.BuiltInClass.direct_slots == []
    @test Jos.BuiltInClass.direct_superclasses == [Jos.Class]
    @test Jos.class_of(Jos.BuiltInClass) === Jos.Class

    @test Jos._Int64.name === :_Int64
    @test Jos._Int64.direct_slots == [:value]
    @test Jos._Int64.direct_superclasses == [Jos.BuiltInClass]
    @test Jos.class_of(Jos._Int64) === Jos.Class

    @test Jos._String.name === :_String
    @test Jos._String.direct_slots == [:value]
    @test Jos._String.direct_superclasses == [Jos.BuiltInClass]
    @test Jos.class_of(Jos._String) === Jos.Class

    # TODO: @defclass(name, super, slots)
end

@testset "2.2 Instances" begin
    @test Jos.class_of(c1) == ComplexNumber
    @test_throws ErrorException Jos.new(ComplexNumber, real=1, imag=2, wrong=3)
end

@testset "2.3 Slot Access" begin
    @test getproperty(c1, :real) === 1
    @test c1.real === 1

    @test_throws ErrorException c1.wrong

    @test setproperty!(c1, :imag, -1) === -1
    c1.imag += 3
    @test c1.imag === 2

    @test_throws ErrorException c1.wrong = 3
end

@testset "2.4 Generic Functions and Methods" begin
    # TODO: @defgeneric
    # TODO: @defmethod
end

@testset "2.5 Pre-defined Generic Functions and Methods" begin 
    # TODO
end

@testset "2.6 MetaObjects" begin
    @test Jos.class_of(c1) === ComplexNumber
    @test ComplexNumber.direct_slots == [:real, :imag]

    @test Jos.class_of(Jos.class_of(c1)) === Jos.Class
    @test Jos.class_of(Jos.class_of(Jos.class_of(c1))) === Jos.Class

    @test Jos.Class.slots == [:name, :direct_slots, :direct_superclasses]
    @test Jos.Class.direct_slots == [:name, :direct_slots, :direct_superclasses]

    @test ComplexNumber.name == :ComplexNumber
    @test ComplexNumber.direct_superclasses == [Jos.Object]

    @test Jos.class_of(add) === Jos.GenericFunction
    @test Jos.GenericFunction.direct_slots == [:name, :params, :methods]
    @test Jos.class_of(add.methods[1]) === Jos.MultiMethod
    @test Jos.MultiMethod.direct_slots == [:procedure, :generic_function, :specializers]
    @test add.methods[1].generic_function === add
end

@testset "2.7 Class Options" begin
    # TODO: waiting for 2.1
end

@testset "2.8 Readers and Writers" begin
    # TODO: waiting for 2.7
end

@testset "2.9 Generic Function Calls" begin
    # TODO
end

@testset "2.10 Multiple Dispatch" begin
    # TODO
end

@testset "2.11 Multiple Inheritance" begin
    # TODO
end

@testset "2.12 Class Hierarchy" begin
    # TODO
end

@testset "2.13 Class Precedence List" begin
    # TODO 
end

@testset "2.14 Built-In Classes" begin
    # TODO
end

@testset "2.15 Introspection" begin
    # TODO
end

@testset "2.16 Meta-Object Protocols" begin
    # TODO
end

@testset "2.16.1 Class Instantiation Protocol" begin
    # TODO
end

@testset "2.16.2 The Compute Slots Protocol" begin
    # TODO
end

@testset "2.16.3 Slot Access Protocol" begin
    # TODO
end

@testset "2.17 Multiple Meta-Class Inheritance" begin
    # TODO
end

@testset "2.18 Extensions" begin
    # TODO ?
end