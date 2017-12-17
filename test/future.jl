# This file is a part of Julia. License is MIT: https://julialang.org/license

using Test
using Base: Next

@testset "Next.copy! for AbstractSet" begin
    for S = (Set, BitSet)
        s = S([1, 2])
        for a = ([1], UInt[1], [3, 4, 5], UInt[3, 4, 5])
            @test s === Next.copy!(s, Set(a)) == S(a)
            @test s === Next.copy!(s, BitSet(a)) == S(a)
        end
    end
end


@testset "Next.copy! for AbstractDict" begin
    s = Dict(1=>2, 2=>3)
    for a = ([3=>4], [0x3=>0x4], [3=>4, 5=>6, 7=>8], Pair{UInt,UInt}[3=>4, 5=>6, 7=>8])
        @test s === Next.copy!(s, Dict(a)) == Dict(a)
        if length(a) == 1 # current limitation of Base.ImmutableDict
            @test s === Next.copy!(s, Base.ImmutableDict(a[])) == Dict(a[])
        end
    end
end

@testset "Next.copy! for AbstractVector" begin
        s = Vector([1, 2])
        for a = ([1], UInt[1], [3, 4, 5], UInt[3, 4, 5])
            @test s === Next.copy!(s, Vector(a)) == Vector(a)
            @test s === Next.copy!(s, SparseVector(a)) == Vector(a)
        end
end

@testset "Next.copy! for AbstractArray" begin
    @test_throws ArgumentError Next.copy!(zeros(2, 3), zeros(3, 2))
    s = zeros(2, 2)
    @test s === Next.copy!(s, fill(1, 2, 2)) == fill(1, 2, 2)
    @test s === Next.copy!(s, fill(1.0, 2, 2)) == fill(1.0, 2, 2)
end
