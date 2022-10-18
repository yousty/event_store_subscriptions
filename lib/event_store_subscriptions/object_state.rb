# frozen_string_literal: true

module EventStoreSubscriptions
  # Defines various states. It is used to set and get current object's state.
  class ObjectState
    attr_accessor :state
    attr_reader :semaphore
    private :state, :state=, :semaphore

    STATES = %i(initial running halting stopped dead).freeze

    def initialize
      initial!
    end

    STATES.each do |state|
      # Checks whether the object is in appropriate state
      # @return [Boolean]
      define_method "#{state}?" do
        self.state == state
      end

      # Sets the state.
      # @return [Symbol]
      define_method "#{state}!" do
        self.state = state
      end
    end

    # @return [String] string representation of the #state
    def to_s
      state.to_s
    end
  end
end
