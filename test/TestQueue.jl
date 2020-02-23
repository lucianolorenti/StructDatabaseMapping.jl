module TestQueue
using Test
using StructDatabaseMapping
const Queue = StructDatabaseMapping.Queue
function test_queue()
    a = Queue(3)
    push!(a, 5)
    push!(a, 5)
    push!(a, 1)
    @test_throws StructDatabaseMapping.Full StructDatabaseMapping.push!_nowait(a, 12)
end
end