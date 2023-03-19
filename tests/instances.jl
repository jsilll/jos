using Test

include("../src/jos.jl")

using .Jos

@testset "New Throws" begin
    # Creating a new class
    ComplexNumber = Jos.MClass(:ComplexNumber, [Jos.Object], [:real, :imag])
    # Test Invalid Slot Name
    @test_throws ErrorException Jos.new(ComplexNumber, real=1, imag=2, wrong=3)
end

@testset "Simple Instance" begin
    # Creating a new class
    ComplexNumber = Jos.MClass(:ComplexNumber, [Jos.Object], [:real, :imag])
    # Test Internal Representation
    @test ComplexNumber.super == [Jos.Object]
    @test ComplexNumber.name === :ComplexNumber
    @test ComplexNumber.direct_slots == [:real, :imag]
    # Test External API
    @test Jos.class_of(ComplexNumber) === Jos.Class

    # Creating a new instance
    c1 = Jos.new(ComplexNumber, real=1, imag=2)
    # Test internal representation
    @test Base.getfield(c1, :class) === ComplexNumber
    @test Base.getfield(c1, :slots) == Dict(:real => 1, :imag => 2)
    # Test External API
    @test c1.real === 1
    c1.imag = 3
    c1.real = 3
    c1.real += 1
    @test c1.real === 4
    c1.real -= 1
    @test c1.real === 3
    @test Jos.class_of(c1) == ComplexNumber
end