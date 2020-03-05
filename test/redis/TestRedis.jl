module TestRedis
using Test 
using Redis
using StructDatabaseMapping
using Dates


DB_NUMBER = 0

include("../includes/basic_test.jl")

function test()
    test_redis()
end
params = (host=get(ENV, "REDIS_HOST", "localhost"),
          db=DB_NUMBER,
          port=parse(Int64, get(ENV, "REDIS_PORT", "6379")))
function cleanup()
    Redis.flushall(
        Redis.RedisConnection(;params...))
end
function test_redis()
    f = ()->Redis.RedisConnection(;params...)
    _test_basic_functionalities(f)
end

end
