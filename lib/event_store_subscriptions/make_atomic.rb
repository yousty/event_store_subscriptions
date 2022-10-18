# frozen_string_literal: true

module EventStoreSubscriptions
  module MakeAtomic
    # Wraps method in Mutex#synchronize to make it atomic. You should have #semaphore method
    # implemented in order this to work.
    # @param method [Symbol] a name of the method
    # @return [Symbol]
    def make_atomic(method)
      module_to_prepend = Module.new do
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{method}(*args, **kwargs, &blk)
          semaphore.synchronize do
            super
          end
        end
        RUBY
      end
      prepend module_to_prepend
      method
    end
  end
end
