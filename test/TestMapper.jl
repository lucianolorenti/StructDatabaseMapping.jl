module TestMapper
using Test
using StructDatabaseMapping
function test_field()
    field = StructDatabaseMapping.Field(:name, Nullable{String})
    @test field.name == :name
    @test field.nullable == true
    #@test field.type == String


    field = StructDatabaseMapping.Field(:name, DBId{Float64})
    @test field.name == :name
    @test field.nullable == true
    #@test field.type == Float64
end
end