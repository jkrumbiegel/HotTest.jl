using HotTest
using Test

maindir = @__DIR__

@testset "HotTest.jl" begin
    @test 1 + 1 == 2
end

@testset "HotTest.jl 2" begin
    @test 1 + 1 == 2
end

@testset "HotTest.jl 3" begin
    @test 1 + 1 == 2
    @testset "Nested HotTest 1" begin
        @test 1 + 1 == 2
    end
    @testset "Nested Test 2" begin
        @test 1 + 1 == 2
    end
end

@testset "Loop test round $i" for i in 1:3
    @test i == i
end

@testset "Nested loop" begin
    @testset "Loop test round $i" for i in 1:3
        @test i == i
    end
end

include("auxiliary.jl")

@test data == 1