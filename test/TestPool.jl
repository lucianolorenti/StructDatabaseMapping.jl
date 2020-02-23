module TestPool
using StructDatabaseMapping
const Pool = StructDatabaseMapping.QueuePool
struct TestConnection
    a::Integer
end
function test_pool()
    pool = Pool(x->TestConnection(5))

end
end