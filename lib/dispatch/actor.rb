module Dispatch
  # Create an Actor that serializes or asynchronizes access to an object
  # Forwards method invocations to the passed object via a private serial queue, 
  # and optinally calls back asynchronously (if given a block or group).
  # Note that this will NOT work for methods that themselves expect a block
  class Actor
    
    instance_methods.each |method|
      undef_method(method) unless method =~ /__(.+)__|method_missing/
    end
  
    # Create an Actor to wrap the given +actee+,
    # optionally specifying the default +callback+ queue
    def initialize(actee, callback=nil)
      @actee = actee
      @callback_default = callback || Dispatch::Queue.concurrent
      @q = Dispatch::Queue.new("dispatch.actor.#{actee}.#{object_id}")
      __reset!__
    end
    
    def __reset!__
      @callback = @callback_default
      @group = nil
    end
    
    # Specify the +callback+ queue for the next async request
    def _on(callback)
      @callback = callback
    end

    # Specify the +group+ for the next async request
    def _with(group)
      @group = group
    end

    # Wait until the internal private queue has completed execution
    # then returns the +actee+ delegate object
    def _done
      @q.sync { }
      @actee
    end
    
    def method_missing(symbol, *args, &block)
      if block_given? || not group.nil?
        callback = @callback
        @q.async(@group) do
          retval = @actee.__send__(symbol, *args)
          callback.async { block.call(retval) } if not callback.nil?
        end
        return __reset!__
      else
        @retval = nil
        @q.sync { @retval = @actee.__send__(symbol, *args) }
        return @retval
      end
    end
  end
end