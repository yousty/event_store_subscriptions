# frozen_string_literal: true

module EventStoreSubscriptions
  class Subscription
    include WaitForFinish

    FORCED_SHUTDOWN_DELAY = 60 # seconds

    attr_accessor :runner
    attr_reader :client, :setup, :state, :position, :statistic
    private :runner, :runner=

    # @param position [EventStoreSubscriptions::SubscriptionPosition, EventStoreSubscriptions::SubscriptionRevision]
    # @param client [EventStoreClient::GRPC::Client]
    # @param setup [EventStoreSubscriptions::SubscriptionSetup]
    # @param statistic [EventStoreSubscriptions::SubscriptionStatistic]
    def initialize(position:, client:, setup:, statistic: SubscriptionStatistic.new)
      @position = position
      @client = client
      @setup = setup
      @state = ObjectState.new
      @statistic = statistic
      @runner = nil
    end

    # Start listening for the events
    # @return [EventStoreSubscriptions::Subscription] returns self
    def listen
      self.runner ||=
        begin
          state.running!
          Thread.new do
            Thread.current.abort_on_exception = false
            Thread.current.report_on_exception = false
            client.subscribe_to_stream(
              *setup.args,
              **adjusted_kwargs,
              &setup.blk
            )
          rescue StandardError => e
            statistic.last_error = e
            statistic.errors_count += 1
            state.dead!
            raise
          end
        end
      self
    end

    # Stops listening for events. This command is async - the result is not immediate. Use the #wait_for_finish 
    # method to wait until the runner has fully stopped.
    # @return [EventStoreSubscriptions::Subscription] returns self
    def stop_listening
      return self unless runner&.alive?

      state.halting!
      Thread.new do
        stopping_at = Time.now.utc
        loop do
          # Give Subscription up to FORCED_SHUTDOWN_DELAY seconds for graceful shutdown
          runner&.exit if Time.now.utc - stopping_at > FORCED_SHUTDOWN_DELAY

          unless runner&.alive?
            state.stopped!
            self.runner = nil
            break
          end
          sleep 0.1
        end
      end
      self
    end

    # Removes all properties of object and freezes it. You can't delete currently running
    #   Subscription though. You must stop it first.
    # @return [EventStoreSubscriptions::Subscription] frozen object
    # @raise [EventStoreSubscriptions::ThreadNotDeadError] raises this error in case runner Thread
    #   is still alive for some reason. Normally this should never happen.
    def delete
      if runner&.alive?
        raise ThreadNotDeadError, "Can not delete alive Subscription #{self.inspect}"
      end

      instance_variables.each { |var| instance_variable_set(var, nil) }
      freeze
    end

    private

    # Wraps original handler into our own handler to provide extended functionality.
    # @param original_handler [#call]
    # @return [Proc]
    def handler(original_handler)
      proc do |result|
        Thread.current.exit unless state.running?
        original_result = result.success
        result = EventStoreClient::GRPC::Shared::Streams::ProcessResponse.new.call(
          original_result,
          *process_response_args
        )
        original_handler.call(result) if result
        statistic.events_processed += 1
        position.update(original_result)
      end
    end

    # Calculates "skip_deserialization" and "skip_decryption" arguments for the ProcessResponse
    # class. Since we have overridden the original handler, we need to calculate the correct argument values
    # to process the response on our own. This method implements the same behavior as
    # the event_store_client gem implements (EventStoreClient::GRPC::Client#subscribe_to_stream
    # method).
    # @return [Array<Boolean>]
    def process_response_args
      skip_deserialization =
        if setup.kwargs.key?(:skip_deserialization)
          setup.kwargs[:skip_deserialization]
        else
          client.config.skip_deserialization
        end
      skip_decryption =
        if setup.kwargs.key?(:skip_decryption)
          setup.kwargs[:skip_decryption]
        else
          client.config.skip_decryption
        end
      [skip_deserialization, skip_decryption]
    end

    # Override keyword arguments, provided by dev in EventStoreSubscriptions::Subscriptions#create
    # or EventStoreSubscriptions::Subscriptions#create_for_all methods. This is needed to provide
    # our own handler and to override the starting position of the given stream.
    # @return [Hash]
    def adjusted_kwargs
      kwargs = setup.dup.kwargs
      kwargs.merge!(handler: handler(kwargs[:handler]), skip_deserialization: true)
      return kwargs unless position.present?

      kwargs[:options] ||= {}
      kwargs[:options].merge!(position.to_option)
      kwargs
    end
  end
end
