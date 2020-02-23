import Pukeko
using Pkg
include("TestQueue.jl")
include("TestPool.jl")
include("TestMapper.jl")
Pukeko.run_tests(TestQueue)
Pukeko.run_tests(TestPool)
Pukeko.run_tests(TestMapper)


Pkg.add(PackageSpec(url="https://github.com/JuliaDatabases/Redis.jl.git"))
include(joinpath(@__DIR__, "redis",  "TestRedis.jl"))
try
    Pukeko.run_tests(TestRedis)
catch e
    TestRedis.cleanup()
    rethrow(e)
end  
Pkg.rm("Redis")

# I have to do  this because LibPQ and SQlite cannot be installed 
# Because there is some incompatibility with Tables.jl

Pkg.add("SQLite")
include(joinpath(@__DIR__, "sqlite",  "TestSQLite.jl"))  
try
    Pukeko.run_tests(TestSQLite)
catch e
    TestSQLite.cleanup()
    rethrow(e)
end
Pkg.rm("SQLite")
Pkg.add("LibPQ")
include(joinpath(@__DIR__, "postgresql",  "TestLibPQ.jl"))
try
    Pukeko.run_tests(TestLibPQ)
catch e
    TestLibPQ.cleanup()
    rethrow(e)
end  
Pkg.rm("LibPQ")




