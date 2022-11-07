data = 1
@testset "auxiliary 2" begin
    @test data == 1
end

@test relpath(@__DIR__, maindir) == "subfolder"