using Test

include("../src/jop.jl")

using .Jop

@testset "ComplexNumber" begin
    ComplexNumber = Jop.MClass(:ComplexNumber, [:real, :imag], [Jop.Object])
    # Test Internal Representation
    @test ComplexNumber.super == [Jop.Object]
    @test ComplexNumber.name == :ComplexNumber
    @test ComplexNumber.slots == [:real, :imag]

    # Test External API
    @test Jop.class_of(ComplexNumber) == Jop.Class

    c1 = Jop.new(ComplexNumber, real=1, imag=2)
    # Internal Representation 
    # Because of Base.getproperty and Base.setproperty!

    # Test External API
    @test c1.real == 1
    @test c1.imag == 2
    @test Jop.class_of(c1) == ComplexNumber

    # Test Invalid Slot Name
    @test_throws ErrorException Jop.new(ComplexNumber, real=1, imag=2, wrong=3)
end