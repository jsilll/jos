using Test, Jos

# ---- Implementing CLOS-like strategy for computing the Class Precedence List ----

function _compute_clos_cpl(cls::JClass) 
    L = JClass[]
    S = Set{JClass}()

    function topo(cls::JClass)
        for c in cls.direct_superclasses
            if !(c in S)
                push!(S, c)
                topo(c)
            end
        end
        insert!(L, 1, cls)
    end

    for c in cls.direct_superclasses
        if !(c in S)
            push!(S, c)
            topo(c)
        end
    end
    insert!(L, 1, cls)
end

const CLOSClass = _new_class(:CLOSClass, Symbol[], [Class])

@defmethod compute_cpl(cls::CLOSClass) = _compute_clos_cpl(cls)

@testset "Extensions - CLOS Class Precedence List" begin
    # -- Test that CLOS Class Precedence List -- 
    A = _new_class(:A, Symbol[], [Object], CLOSClass)
    B = _new_class(:B, Symbol[], [Object], CLOSClass)
    C = _new_class(:C, Symbol[], [Object], CLOSClass)
    D = _new_class(:D, Symbol[], [A, B], CLOSClass)
    E = _new_class(:E, Symbol[], [A, C], CLOSClass)
    F = _new_class(:F, Symbol[], [D, E], CLOSClass)

    @test compute_cpl(F) == [F, E, C, D, B, A, Object, Top]
end

# ---- Implementing additional metaobject protocols ----

@defmethod compute_defaulted(cls::Class) = Jos._compute_defaulted(cls)

@defmethod compute_meta_slots(cls::Class) = Jos._compute_meta_slots(cls)

function _extended_new_class(name::Symbol, direct_slots::Vector{Symbol},
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
    cls.defaulted = compute_defaulted(cls)
    cls.meta_slots = compute_meta_slots(cls)

    for slot in cls.slots
        cls.getters[slot], cls.setters[slot] = compute_getter_and_setter(cls, slot, 0)
    end

    cls
end

@testset "Extensions - Additional Meta Object Protocols" begin
    # -- Test that CLOS Class Precedence List -- 

    # Just testing that normal functionality is not broken
    # Additonal test cases could be added to test the new functionality
    # of compute_defaulted and compute_meta_slots
    A = _extended_new_class(:A, Symbol[], [Object])
    
    @test A.name === :A

    @test A.cpl == [A, Object, Top]
    @test A.direct_superclasses == [Object]

    @test A.slots == []
    @test A.direct_slots == []

    @test A.defaulted == Dict{Symbol,Any}()

    @test class_of(A) === Class
end