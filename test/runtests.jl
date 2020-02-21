import Pukeko
using Pkg
include("TestQueue.jl")
include("TestPool.jl")
include("TestMapper.jl")
Pukeko.run_tests(TestQueue)
Pukeko.run_tests(TestPool)
Pukeko.run_tests(TestMapper)

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




