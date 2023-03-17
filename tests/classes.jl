using Test

include("../src/jop.jl")

using .Jop

@testset "Class Class" begin
    # Internal Representation
    @test Jop.Class.slots == []
    @test Jop.Class.name == :Class
    @test Jop.Class.super == [Jop.Object]
    
    # External API
    @test Jop.class_of(Jop.Class) == Jop.Class
end

@testset "Object Class" begin
    # Internal Representation
    @test Jop.Object.super == []
    @test Jop.Object.slots == []
    @test Jop.Object.name == :Object
    
    # External API
    @test Jop.class_of(Jop.Object) == Jop.Class
end