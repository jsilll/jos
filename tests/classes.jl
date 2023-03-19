using Test

include("../src/jos.jl")

using .Jos

@testset "Classes" begin
    # Internal Representation
    @test Jos.Top.super == []
    @test Jos.Top.name === :Top
    @test Jos.Top.direct_slots == []
    # External API
    @test Jos.class_of(Jos.Top) === Jos.Class

    # Internal Representation
    @test Jos.Object.name === :Object
    @test Jos.Object.super == [Jos.Top]
    @test Jos.Object.direct_slots == []
    # External API
    @test Jos.class_of(Jos.Object) === Jos.Class
    
    # Internal Representation
    @test Jos.Method.name === :Method
    @test Jos.Method.super == [Jos.Top]
    @test Jos.Method.direct_slots == []
    # External API
    @test Jos.class_of(Jos.Method) === Jos.Class

    # Internal Representation
    @test Jos.MetaObject.name === :MetaObject
    @test Jos.MetaObject.super == [Jos.Object]
    @test Jos.MetaObject.direct_slots == []
    # External API
    @test Jos.class_of(Jos.MetaObject) === Jos.Class

    # Internal Representation
    @test Jos.Class.name === :Class
    @test Jos.Class.direct_slots == []
    @test Jos.Class.super == [Jos.MetaObject]
    # External API
    @test Jos.class_of(Jos.Class) === Jos.Class

    # Internal Representation
    @test Jos.BuiltInClass.name === :BuiltInClass
    @test Jos.BuiltInClass.direct_slots == []
    @test Jos.BuiltInClass.super == [Jos.Class]
    # External API
    @test Jos.class_of(Jos.BuiltInClass) === Jos.Class

    # Internal Representation
    @test Jos.GenericFunction.name === :GenericFunction
    @test Jos.GenericFunction.direct_slots == []
    @test Jos.GenericFunction.super == [Jos.Method, Jos.MetaObject]
    # External API
    @test Jos.class_of(Jos.GenericFunction) === Jos.Class

    # Internal Representation
    @test Jos._Int64.name === :_Int64
    @test Jos._Int64.direct_slots == [:value]
    @test Jos._Int64.super == [Jos.BuiltInClass]
    # External API
    @test Jos.class_of(Jos._Int64) === Jos.Class

    # Internal Representation
    @test Jos._String.name === :_String
    @test Jos._String.direct_slots == [:value]
    @test Jos._String.super == [Jos.BuiltInClass]
    # External API
    @test Jos.class_of(Jos._String) === Jos.Class
end