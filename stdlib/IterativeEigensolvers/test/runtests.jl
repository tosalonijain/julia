# This file is a part of Julia. License is MIT: https://julialang.org/license

using IterativeEigensolvers
using Test

@testset "eigs" begin
    srand(1234)
    n = 10
    areal  = sprandn(n,n,0.4)
    breal  = sprandn(n,n,0.4)
    acmplx = complex.(sprandn(n,n,0.4), sprandn(n,n,0.4))
    bcmplx = complex.(sprandn(n,n,0.4), sprandn(n,n,0.4))

    testtol = 1e-6

    @testset for elty in (Float64, ComplexF64)
        if elty == ComplexF32 || elty == ComplexF64
            a = acmplx
            b = bcmplx
        else
            a = areal
            b = breal
        end
        a_evs = eigvals(Array(a))
        a     = convert(SparseMatrixCSC{elty}, a)
        asym  = a' + a                  # symmetric indefinite
        apd   = a'*a                    # symmetric positive-definite

        b     = convert(SparseMatrixCSC{elty}, b)
        bsym  = b' + b
        bpd   = b'*b

        (d,v) = eigs(a, nev=3)
        @test a*v[:,2] ≈ d[2]*v[:,2]
        @test norm(v) > testtol # eigenvectors cannot be null vectors
        (d,v) = eigs(a, I, nev=3) # test eigs(A, B; kwargs...)
        @test a*v[:,2] ≈ d[2]*v[:,2]
        @test norm(v) > testtol # eigenvectors cannot be null vectors
        @test_logs (:warn,"Use symbols instead of strings for specifying which eigenvalues to compute") eigs(a, which="LM")
        @test_logs (:warn,"Adjusting ncv from 1 to 4") eigs(a, ncv=1, nev=2)
        @test_logs (:warn,"Adjusting nev from $n to $(n-2)") eigs(a, nev=n)
        # (d,v) = eigs(a, b, nev=3, tol=1e-8) # not handled yet
        # @test a*v[:,2] ≈ d[2]*b*v[:,2] atol=testtol
        # @test norm(v) > testtol # eigenvectors cannot be null vectors
        if elty <: Base.LinAlg.BlasComplex
            sr_ind = indmin(real.(a_evs))
            (d, v) = eigs(a, nev=1, which=:SR)
            @test d[1] ≈ a_evs[sr_ind]
            si_ind = indmin(imag.(a_evs))
            (d, v) = eigs(a, nev=1, which=:SI)
            @test d[1] ≈ a_evs[si_ind]
            lr_ind = indmax(real.(a_evs))
            (d, v) = eigs(a, nev=1, which=:LR)
            @test d[1] ≈ a_evs[lr_ind]
            li_ind = indmax(imag.(a_evs))
            (d, v) = eigs(a, nev=1, which=:LI)
            @test d[1] ≈ a_evs[li_ind]
        end

        (d,v) = eigs(asym, nev=3)
        @test asym*v[:,1] ≈ d[1]*v[:,1]
        @test eigs(asym; nev=1, sigma=d[3])[1][1] ≈ d[3]
        @test norm(v) > testtol # eigenvectors cannot be null vectors

        (d,v) = eigs(apd, nev=3)
        @test apd*v[:,3] ≈ d[3]*v[:,3]
        @test eigs(apd; nev=1, sigma=d[3])[1][1] ≈ d[3]

        (d,v) = eigs(apd, bpd, nev=3, tol=1e-8)
        @test apd*v[:,2] ≈ d[2]*bpd*v[:,2] atol=testtol
        @test norm(v) > testtol # eigenvectors cannot be null vectors

        @testset "(shift-and-)invert mode" begin
            (d,v) = eigs(apd, nev=3, sigma=0)
            @test apd*v[:,3] ≈ d[3]*v[:,3]
            @test norm(v) > testtol # eigenvectors cannot be null vectors

            (d,v) = eigs(apd, bpd, nev=3, sigma=0, tol=1e-8)
            @test apd*v[:,1] ≈ d[1]*bpd*v[:,1] atol=testtol
            @test norm(v) > testtol # eigenvectors cannot be null vectors
        end

        @testset "ArgumentErrors" begin
            @test_throws ArgumentError eigs(rand(elty,2,2))
            @test_throws ArgumentError eigs(a, nev=-1)
            @test_throws ArgumentError eigs(a, which=:Z)
            @test_throws ArgumentError eigs(a, which=:BE)
            @test_throws DimensionMismatch eigs(a, v0=zeros(elty,n+2))
            @test_throws ArgumentError eigs(a, v0=zeros(Int,n))
            if elty == Float64
                @test_throws ArgumentError eigs(a + transpose(a), which=:SI)
                @test_throws ArgumentError eigs(a + transpose(a), which=:LI)
                @test_throws ArgumentError eigs(a, sigma = rand(ComplexF32))
            end
        end
    end

    @testset "Symmetric generalized with singular B" begin
        srand(127)
        n = 10
        k = 3
        A = randn(n,n); A = A'A
        B = randn(n,k); B = B*B'
        @test sort(eigs(A, B, nev = k, sigma = 1.0)[1]) ≈ sort(eigvals(A, B)[1:k])
    end
end

# Problematic example from #6965A
let A6965 = [
    1.0   1.0   1.0   1.0   1.0   1.0   1.0  1.0
    -1.0   2.0   0.0   0.0   0.0   0.0   0.0  1.0
    -1.0   0.0   3.0   0.0   0.0   0.0   0.0  1.0
    -1.0   0.0   0.0   4.0   0.0   0.0   0.0  1.0
    -1.0   0.0   0.0   0.0   5.0   0.0   0.0  1.0
    -1.0   0.0   0.0   0.0   0.0   6.0   0.0  1.0
    -1.0   0.0   0.0   0.0   0.0   0.0   7.0  1.0
    -1.0  -1.0  -1.0  -1.0  -1.0  -1.0  -1.0  8.0
]
    d, = eigs(A6965,which=:SM,nev=2,ncv=4,tol=eps())
    @test d[1] ≈ 2.5346936860350002
    @test real(d[2]) ≈ 2.6159972444834976
    @test abs(imag(d[2])) ≈ 1.2917858749046127

    # Requires ARPACK 3.2 or a patched 3.1.5
    #T6965 = [ 0.9  0.05  0.05
    #          0.8  0.1   0.1
    #          0.7  0.1   0.2 ]
    #d,v,nconv = eigs(T6965,nev=1,which=:LM)
    # @test T6965*v ≈ d[1]*v atol=1e-6
end

# Example from Quantum Information Theory
import Base: size, issymmetric, ishermitian

mutable struct CPM{T<:Base.LinAlg.BlasFloat} <: AbstractMatrix{T} # completely positive map
    kraus::Array{T,3} # kraus operator representation
end
size(Phi::CPM) = (size(Phi.kraus,1)^2,size(Phi.kraus,3)^2)
issymmetric(Phi::CPM) = false
ishermitian(Phi::CPM) = false
function Base.LinAlg.mul!(rho2::StridedVector{T},Phi::CPM{T},rho::StridedVector{T}) where {T<:Base.LinAlg.BlasFloat}
    rho = reshape(rho,(size(Phi.kraus,3),size(Phi.kraus,3)))
    rho1 = zeros(T,(size(Phi.kraus,1),size(Phi.kraus,1)))
    for s = 1:size(Phi.kraus,2)
        As = view(Phi.kraus,:,s,:)
        rho1 += As*rho*As'
    end
    return copyto!(rho2,rho1)
end
Base.LinAlg.A_mul_B!(rho2::StridedVector{T},Phi::CPM{T},rho::StridedVector{T}) where {T<:Base.LinAlg.BlasFloat} = Base.LinAlg.mul!(rho2, Phi, rho)
# after the A_mul_B! deprecation, remove this A_mul_B! def

let
    # Generate random isometry
    (Q,R) = qr(randn(100,50))
    Q = reshape(Q,(50,2,50))
    # Construct trace-preserving completely positive map from this
    Phi = CPM(copy(Q))
    (d,v,nconv,numiter,numop,resid) = eigs(Phi,nev=1,which=:LM)
    # Properties: largest eigenvalue should be 1, largest eigenvector, when reshaped as matrix
    # should be a Hermitian positive definite matrix (up to an arbitrary phase)

    @test d[1] ≈ 1. # largest eigenvalue should be 1.
    v = reshape(v,(50,50)) # reshape to matrix
    v /= trace(v) # factor out arbitrary phase
    @test vecnorm(imag(v)) ≈ 0. # it should be real
    v = real(v)
    # @test vecnorm(v-v')/2 ≈ 0. # it should be Hermitian
    # Since this fails sometimes (numerical precision error),this test is commented out
    v = (v+v')/2
    @test isposdef(v)

    # Repeat with starting vector
    (d2,v2,nconv2,numiter2,numop2,resid2) = eigs(Phi,nev=1,which=:LM,v0=reshape(v,(2500,)))
    v2 = reshape(v2,(50,50))
    v2 /= trace(v2)
    @test numiter2 < numiter
    @test v ≈ v2

    # Adjust the tolerance a bit since matrices with repeated eigenvalues
    # can be very stressful to ARPACK and this may therefore fail with
    # info = 3 if the tolerance is too small
    @test eigs(sparse(1.0I, 50, 50), nev=10, tol = 5e-16)[1] ≈ ones(10) #Issue 4246
end

@testset "real svds" begin
    A = sparse([1, 1, 2, 3, 4], [2, 1, 1, 3, 1], [2.0, -1.0, 6.1, 7.0, 1.5])
    S1 = svds(A, nsv = 2)
    S2 = svd(Array(A))

    ## singular values match:
    @test S1[1][:S] ≈ S2[2][1:2]
    @testset "singular vectors" begin
        ## 1st left singular vector
        s1_left = sign(S1[1][:U][3,1]) * S1[1][:U][:,1]
        s2_left = sign(S2[1][3,1]) * S2[1][:,1]
        @test s1_left ≈ s2_left

        ## 1st right singular vector
        s1_right = sign(S1[1][:V][3,1]) * S1[1][:V][:,1]
        s2_right = sign(S2[3][3,1]) * S2[3][:,1]
        @test s1_right ≈ s2_right
    end
    # Issue number 10329
    # Ensure singular values from svds are in
    # the correct order
    @testset "singular values ordered correctly" begin
        B = sparse(Diagonal([1.0, 2.0, 34.0, 5.0, 6.0]))
        S3 = svds(B, ritzvec=false, nsv=2)
        @test S3[1][:S] ≈ [34.0, 6.0]
        S4 = svds(B, nsv=2)
        @test S4[1][:S] ≈ [34.0, 6.0]
    end
    @testset "passing guess for Krylov vectors" begin
        S1 = svds(A, nsv = 2, v0=rand(eltype(A),size(A,2)))
        @test S1[1][:S] ≈ S2[2][1:2]
    end

    @test_throws ArgumentError svds(A,nsv=0)
    @test_throws ArgumentError svds(A,nsv=20)
    @test_throws DimensionMismatch svds(A,nsv=2,v0=rand(size(A,2)+1))

    @testset "Orthogonal vectors with repeated singular values $i times. Issue 16608" for i in 2:3
        rng = MersenneTwister(126) # Fragile to compute repeated values without blocking so we set the seed
        v0  = randn(rng, 20)
        d   = sort(rand(rng, 20), rev = true)
        for j in 2:i
            d[j] = d[1]
        end
        A = qr(randn(rng, 20, 20))[1]*Diagonal(d)*qr(randn(rng, 20, 20))[1]
        @testset "Number of singular values: $j" for j in 2:6
            # Default size of subspace
            F = svds(A, nsv = j, v0 = v0)
            @test F[1][:U]'F[1][:U] ≈ Matrix(I, j, j)
            @test F[1][:V]'F[1][:V] ≈ Matrix(I, j, j)
            @test F[1][:S]          ≈ d[1:j]
            for k in 3j:2:5j
                # Custom size of subspace
                F = svds(A, nsv = j, ncv = k, v0 = v0)
                @test F[1][:U]'F[1][:U] ≈ Matrix(I, j, j)
                @test F[1][:V]'F[1][:V] ≈ Matrix(I, j, j)
                @test F[1][:S]          ≈ d[1:j]
            end
        end
    end
end

@testset "complex svds" begin
    A = sparse([1, 1, 2, 3, 4], [2, 1, 1, 3, 1], exp.(im*[2.0:2:10;]), 5, 4)
    S1 = svds(A, nsv = 2)
    S2 = svd(Array(A))

    ## singular values match:
    @test S1[1][:S] ≈ S2[2][1:2]
    @testset "singular vectors" begin
        ## left singular vectors
        s1_left = abs.(S1[1][:U][:,1:2])
        s2_left = abs.(S2[1][:,1:2])
        @test s1_left ≈ s2_left

        ## right singular vectors
        s1_right = abs.(S1[1][:V][:,1:2])
        s2_right = abs.(S2[3][:,1:2])
        @test s1_right ≈ s2_right
    end
    @testset "passing guess for Krylov vectors" begin
        S1 = svds(A, nsv = 2, v0=rand(eltype(A),size(A,2)))
        @test S1[1][:S] ≈ S2[2][1:2]
    end

    @test_throws ArgumentError svds(A,nsv=0)
    @test_throws ArgumentError svds(A,nsv=20)
    @test_throws DimensionMismatch svds(A,nsv=2,v0=complex(rand(size(A,2)+1)))
end

@testset "promotion" begin
    eigs(rand(1:10, 10, 10))
    eigs(rand(1:10, 10, 10), rand(1:10, 10, 10) |> t -> t't)
    svds(rand(1:10, 10, 8))
    @test_throws MethodError eigs(big.(rand(1:10, 10, 10)))
    @test_throws MethodError eigs(big.(rand(1:10, 10, 10)), rand(1:10, 10, 10))
    @test_throws MethodError svds(big.(rand(1:10, 10, 8)))
end
