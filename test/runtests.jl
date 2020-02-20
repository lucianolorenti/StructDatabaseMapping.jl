




include("TestQueue.jl")
include("TestPool.jl")
include("TestRelational.jl")
import Pukeko

Pukeko.run_tests(TestQueue)

Pukeko.run_tests(TestPool)
try
    Pukeko.run_tests(TestRelational)
catch e
    TestRelational.cleanup()
    rethrow(e)
end
