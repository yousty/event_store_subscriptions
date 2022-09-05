# frozen_string_literal: true

module EventStoreSubscriptions
  # This class is used to persist and update commit_position and prepare_position when subscribing
  # to "$all" stream.
  class SubscriptionPosition < Struct.new(:commit_position, :prepare_position)
    attr_reader :update_hooks

    def initialize(*)
      super
      @update_hooks = []
    end

    # Updates the position from GRPC response.
    # @param response [EventStore::Client::Streams::ReadResp] GRPC EventStore object. See its
    #   structure in the lib/event_store_client/adapters/grpc/generated/streams_pb.rb file in
    #   `event_store_client` gem.
    # @return [Boolean] whether the position was updated
    def update(response)
      source = response.checkpoint || response.event&.event
      return false unless source

      # Updating position values in memory first to prevent the situation when update hook fails and,
      # thus keeping the position not up to date
      self.commit_position, self.prepare_position =
        source.commit_position, source.prepare_position

      update_hooks.each do |handler|
        handler.call(self)
      end
      true
    end

    # Adds a handler that will be executed when the position gets updates. You may add as many
    # handlers as you want.
    # Example:
    #   ```ruby
    #   instance.register_update_hook do |position|
    #     # do something with the position. E.g. persist it somewhere
    #   end
    #   instance.register_update_hook do |position|
    #     # do something else with the position
    #   end
    #   ```
    # @return [void]
    def register_update_hook(&blk)
      update_hooks << blk
    end

    # Checks if position's properties are absent
    # @return [Boolean]
    def empty?
      commit_position.nil? && prepare_position.nil?
    end

    # Checks if position's properties are present
    # @return [Boolean]
    def present?
      !empty?
    end

    # Constructs a hash compatible for usage with EventStoreClient::GRPC::Client#subscribe_to_stream
    # method. You can pass it into :options keyword argument of that method to set the starting
    # position of the stream.
    # @return [Hash]
    def to_option
      { from_position: { commit_position: commit_position, prepare_position: prepare_position } }
    end
  end
end
