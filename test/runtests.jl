




include("TestQueue.jl")
include("TestPool.jl")
include("TestRelational.jl")
import Pukeko
Pukeko.run_tests(TestQueue)
Pukeko.run_tests(TestPool)
Pukeko.run_tests(TestRelational)
