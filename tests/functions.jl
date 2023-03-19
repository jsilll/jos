using Test

using .Jos

@testset "Empty Generic Function" begin
    # Create a new Generic Function
    add = Jos.MGenericFunction(:add, [:x, :y], [])
    # Internal Representation
    @test add.name === :add
    @test add.methods == []
    @test add.params == [:x, :y]
    # External API
    @test Jos.class_of(add) === Jos.GenericFunction
    @test_throws MethodError add(1, 2)
end

@testset "Simple Generic Function" begin
    # Create a new Generic Function
    add = Jos.MGenericFunction(:add, [:x, :y], [])
    # Internal Representation
    @test add.name === :add
    @test add.methods == []
    @test add.params == [:x, :y]
    # External API
    @test Jos.class_of(add) === Jos.GenericFunction

    # Create a new Method (simulate the macro expansion)
    add_int = Jos.MMethod(:add, (x, y) -> x + y,
        [
            (:x, Jos._Int64),
            (:y, Jos._Int64),
        ])
    push!(add.methods, add_int)
    # Internal Representation
    @test add_int.name === :add
    @test add_int.params == [:x, :y]
    @test add_int.types == [
        (:x, Jos._Int64),
        (:y, Jos._Int64),
    ]
    @test add_int.method == (x, y) -> x + y
    @test add.methods == [add_int]
    # External API
    @test Jos.class_of(add_int) === Jos.Method

    # Create new instances of Int64
    i1 = Jos.MInstance(Jos._Int64, 1)
    i2 = Jos.MInstance(Jos._Int64, 2)
    # External API
    @test Jos.add(c1, c2) == Jos.new(Jos._Int64, value=3)
end