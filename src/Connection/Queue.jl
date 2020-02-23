

import Base: isempty, push!, length

struct Empty <: Exception end
struct Full <: Exception end


struct Queue
    maxsize::Integer
    uselifo::Bool
    """
    mutex must be held whenever the queue is mutating.  All methods
    that acquire mutex must release it before returning.  mutex
    is shared between the two conditions, so acquiring and
    releasing the conditions also acquires and releases mutex.
    """
    mutex::ReentrantLock
    """
    Notify not_empty whenever an item is added to the queue; a
    thread waiting to get is notified then.
    """
    not_empty::Threads.Condition
    """
    Notify not_full whenever an item is removed from the queue;
    a thread waiting to put is notified then
    """
    not_full::Threads.Condition
    queue::Array
end

"""
   function Queue(maxsize::Integer=0, use_lifo::Bool=false)

Initialize a queue object with a given maximum size.

If `maxsize` is <= 0, the queue size is infinite.

If `use_lifo` is True, this Queue acts like a Stack (LIFO).
"""
function Queue(maxsize::Integer=0, uselifo::Bool=false)
    mutex = ReentrantLock()
    return Queue(maxsize, uselifo, mutex, Threads.Condition(mutex), Threads.Condition(mutex), [])
end


"""
    function length(q::Queue) :: Integer

Return the approximate size of the queue (not reliable!).
"""
function length(q::Queue) :: Integer
    lock(q.mutex)
    n = _length(q)
    unlock(q.mutex)
    return n
end

"""
    function isempty(q::Queue) :: Bool

Return True if the queue is empty, False otherwise (not reliable!).
"""
function isempty(q::Queue) :: Bool
    lock(q.mutex)
    n = _isempty(q)
    unlock(q.mutex)
    return n
end

"""
    function full(q::Queue) :: Bool

Return True if the queue is full, False otherwise (not reliable!).
"""

function full(q::Queue) :: Bool
    lock(q.mutex)
    n = _full(q)
    unlock(q.mutex)
    return n
end

"""

    function push!(q::Queue, item, block::Bool=true, timeout::Union{Integer, Nothing} = nothing)

Put an item into the queue.

        If optional args `block` is True and `timeout` is None (the
        functionault), block if necessary until a free slot is
        available. If `timeout` is a positive number, it blocks at
        most `timeout` seconds and raises the ``Full`` exception if no
        free slot was available within that time.  Otherwise (`block`
        is false), put an item on the queue if a free slot is
        immediately available, else raise the ``Full`` exception
        (`timeout` is ignored in that case).
        """

function push!(q::Queue, item, block::Bool=true, timeout::Union{Integer, Nothing} = nothing)
    lock(q.not_full)
    try
        if !block
            if _isfull(q)
                throw(Full())
            end
        elseif timeout == nothing
            while _isfull(q)
                wait(q.not_full)
            end
        else
            if timeout < 0
                throw(ArgumentError("'timeout' must be a positive number"))
              end
            endtime = _time() + timeout
            while _isfull(q)
                remaining = endtime - _time()
                if remaining <= 0.0
                    throw(Full())
                end
                wait(q.not_full)
                #self.not_full.wait(remaining)
            end
        end
        _push!(q, item)
        notify(q.not_empty)
     finally
        unlock(q.not_full)
     end
end

"""

Put an item into the queue without blocking.

Only enqueue the item if a free slot is immediately available.
Otherwise raise the ``Full`` exception.
        """
push!_nowait(q::Queue, item) = push!(q, item, false)
        """Remove and return an item from the queue.

        If optional args `block` is True and `timeout` is None (the
        functionault), block if necessary until an item is available. If
        `timeout` is a positive number, it blocks at most `timeout`
        seconds and raises the ``Empty`` exception if no item was
        available within that time.  Otherwise (`block` is false),
        return an item if one is immediately available, else raise the
        ``Empty`` exception (`timeout` is ignored in that case).
        """
    function get(q::Queue, block::Bool=true, timeout::Union{Integer, Nothing}=nothing)
        lock(q.not_empty)
        try
            if !block
                if _isempty(q)
                    raise(Empty)
                end
            elseif timeout === None
                while _isempty(q)
                    wait(q.not_empty)
                end
            else
                if timeout < 0
                    raise(ValueError("'timeout' must be a positive number"))
                end
                endtime = _time() + timeout
                while _isempty(q)
                    remaining = endtime - _time()
                    if remaining <= 0.0
                        raise(Empty)
                    end
                    wait(q.not_empty)
                    #self.not_empty.wait(remaining)
                end
            end
            item = _get(q)
            notify(q.not_full)
            return item
        finally
            unlock(q.not_empty)
        end
    end

      """Remove and return an item from the queue without blocking.

        Only get an item if one is immediately available. Otherwise
        raise the ``Empty`` exception.
        """

get_nowait(q::Queue) = get(q)

#Override these methods to implement other queue organizations
    # (e.g. stack or priority queue).
    # These will only be called with appropriate locks held

    # Initialize the queue representation


function _qsize(q::Queue) :: Integer
    return length(q.queue)
end

function _isempty(q::Queue) :: Bool
    return isempty(q.queue)
end

function _isfull(q::Queue) :: Bool
    return q.maxsize > 0 && length(q.queue) == q.maxsize
end

function _push!(q::Queue, item)
    push!(q.queue, item)
end

function _get(q::Queue)
    if q.use_lifo
        # LIFO
        return pop!(q.queue)
    else
        # FIFO
        return popfirst!(q.queue)
    end
end
