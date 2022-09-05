# frozen_string_literal: true

module EventStoreSubscriptions
  # Defines various states. It is used to set and get current object's state.
  class ObjectState
    attr_accessor :last_error, :state, :semaphore
    private :state, :state=, :semaphore

    STATES = %i(initial running halting stopped dead).freeze

    def initialize
      @last_error = nil
      @semaphore = Mutex.new
      initial!
    end

    STATES.each do |state|
      # @return [Boolean]
      define_method "#{state}?" do
        semaphore.synchronize { self.state == state }
      end

      # Sets the state.
      # @return [Symbol]
      define_method "#{state}!" do
        semaphore.synchronize { self.state = state }
      end
    end

    def to_s
      state.to_s
    end
  end
end
