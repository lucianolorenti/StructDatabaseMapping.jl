
using Pkg
using Test
using StructDatabaseMapping
@testset "Connections" begin
     @testset "Queue" begin
        include("TestQueue.jl")
    end
    @testset "Pool" begin
        include("TestPool.jl")
    end 
end
@testset "Mapper" begin
    include("TestMapper.jl")
end

@testset "Redis" begin
    Pkg.add(PackageSpec(url="https://github.com/JuliaDatabases/Redis.jl.git"))
    include(joinpath(@__DIR__, "redis",  "TestRedis.jl"))
    
    try
        TestRedis.test()
    finally 
        TestRedis.cleanup()
    end  
    Pkg.rm("Redis") 
end
# I have to do  this because LibPQ and SQlite cannot be installed 
# Because there is some incompatibility with Tables.jl
@testset "SQLite" begin
    Pkg.add("SQLite")
    include(joinpath(@__DIR__, "sqlite",  "TestSQLite.jl"))  
    try
        TestSQLite.test()
        TestSQLite.test_cleanup()
    finally
        TestSQLite.cleanup()
    end
    Pkg.rm("SQLite")
end
@testset "PostgreSQL" begin
    Pkg.add("LibPQ")
    include(joinpath(@__DIR__, "postgresql",  "TestLibPQ.jl"))
    try
        TestLibPQ.test()
    finally
        TestLibPQ.cleanup()
    end  
    Pkg.rm("LibPQ")
end