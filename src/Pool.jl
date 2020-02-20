include("Queue.jl")

abstract type ConnectionPool end
function close!(conn) end
function Base.open(f::Function, r::Connection)
    conn = get_connection!(r)
    try
        f(conn)
    finally
        release_connection!(r, conn)
    end
end

get_connection(r::ConnectionPool) = throw(NotImplementedError())
release_connection(r::ConnectionPool, opened_connection) = throw(NotImplementedError())

struct SimplePool <: ConnectionPool
    creator::Function
    dbtype::DataType
    function SimplePool(creator::Function)
        conn = creator()
        dbtype = typeof(conn)
        println(dbtype)
        close!(conn)
        return new(creator, dbtype)
    end
end
get_connection(r::SimplePool) = r.creator()
release_connection(r::SimplePool, conn) =  close!(conn)


"""A :class:`.Pool` that imposes a limit on the number of open connections.
    :class:`.QueuePool` is the default pooling implementation used for
    all :class:`.Engine` objects, unless the SQLite dialect is in use.
    """

struct QueuePool <: ConnectionPool
    creator::Function
    _pool::Queue
    overflow::Integer
    max_overflow::Integer
    timeout::Integer
    uselifo::Bool
    _overflow_lock::ReentrantLock
    recycle::Bool
    reset_on_return::Bool

end
"""

Arguments
--------
:param creator: a callable function that returns a DB-API
          connection object, same as that of :paramref:`.Pool.creator`.
        :param pool_size: The size of the pool to be maintained,
          defaults to 5. This is the largest number of connections that
          will be kept persistently in the pool. Note that the pool
          begins with no connections; once this number of connections
          is requested, that number of connections will remain.
          ``pool_size`` can be set to 0 to indicate no size limit; to
          disable pooling, use a :class:`~sqlalchemy.pool.NullPool`
          instead.
        :param max_overflow: The maximum overflow size of the
          pool. When the number of checked-out connections reaches the
          size set in pool_size, additional connections will be
          returned up to this limit. When those additional connections
          are returned to the pool, they are disconnected and
          discarded. It follows then that the total number of
          simultaneous connections the pool will allow is pool_size +
          `max_overflow`, and the total number of "sleeping"
          connections the pool will allow is pool_size. `max_overflow`
          can be set to -1 to indicate no overflow limit; no limit
          will be placed on the total number of concurrent
          connections. Defaults to 10.
        :param timeout: The number of seconds to wait before giving up
          on returning a connection. Defaults to 30.
        :param use_lifo: use LIFO (last-in-first-out) when retrieving
          connections instead of FIFO (first-in-first-out). Using LIFO, a
          server-side timeout scheme can reduce the number of connections used
          during non-peak periods of use.   When planning for server-side
          timeouts, ensure that a recycle or pre-ping strategy is in use to
          gracefully handle stale connections.
          .. versionadded:: 1.3
          .. seealso::
            :ref:`pool_use_lifo`
            :ref:`pool_disconnects`
        :param **kw: Other keyword arguments including
          :paramref:`.Pool.recycle`, :paramref:`.Pool.echo`,
          :paramref:`.Pool.reset_on_return` and others are passed to the
          :class:`.Pool` constructor.
"""
function QueuePool(creator::Function; poolsize::Integer=5, max_overflow::Integer=10,
                   timeout::Integer=30, use_lifo::Bool=false, recycle::Bool=false,
                   reset_on_return::Bool=false)
    return QueuePool(creator, Queue(poolsize, use_lifo), 0-poolsize,
                     max_overflow, timeout, use_lifo, ReentrantLock(), recycle,
                     reset_on_return)
end
function _do_return_conn(p::QueuePool, conn)
    try
        push!(p._pool, conn, false)
    catch e
        if isa(e, Full)
            try
                close(conn)
            finally
                _dec_overflow(p)
            end
        end
    end
end
function _do_get(q::QueuePool)
    use_overflow = q._max_overflow > -1
    try
        wait = use_overflow && (q._overflow >= q._max_overflow)
        return get(q._pool, wait, self._timeout)
    catch e
                # don't do things inside of "except Empty", because when we say
        # we timed out or can't connect and raise, Python 3 tells
        # people the real error is queue.Empty which it isn't.

        if !isa(e, Empty)
            throw(RuntimeError())
        end

    end
    if use_overflow && (q._overflow >= q._max_overflow)
        if  wait
            return _do_get(q)
        else
            throw(TimeoutError(
                """
                QueuePool limit of size $(length(d)) overflow $(overflow(q)) reached,
                connection timed out, timeout $(q._timeout)
                """
            ))
        end
    end
    if _inc_overflow(q)
        try
            return _create_connection(q)
        catch
            _dec_overflow(q)
        end
    else
        return _do_get(q)
    end
end
function _inc_overflow(q::QueuePool)
    if self._max_overflow == -1
        self._overflow += 1
        return true
    end
    b = true
    lock(q._overflow_lock)
    if self._overflow < self._max_overflow
        self._overflow += 1
        b =  true
    else
        b = false
    end
    unlock(q._overflow_lock)
    return b
end

function _dec_overflow(q::QueuePool)
    if q._max_overflow == -1
        q._overflow -= 1
        return true
    end
    lock(q._overflow_lock)
    q._overflow -= 1
    unlock(q._overflow_lock)
    return true
end

function dispose(q::QueuePool)
    while true
        try
            conn = get(q._pool, false)
            close(conn)
        catch Empty
            break
        end
        q._overflow = 0 - length(q)
        @info("Pool disposed. %s", self.status())
    end
end


function status(q::QueuePool)
    return """
                    Pool size: $(length(q))  Connections in pool: $(checkedin(q))
                    Current Overflow: $(overflow(q)) Current Checked out
                connections: $(checkedout(q))
                """
    end

function size(q::QueuePool)
    return q._pool.maxsize
end
function timeout(q::QueuePool)
    return q._timeout
end
function checkedin(q::QueuePool)
    return length(q._pool)
end
function overflow(q::QueuePool)
    return q._overflow
end
function checkedout(q::QueuePool)
    return q._pool.maxsize - length(q._pool) + self._overflow
end



