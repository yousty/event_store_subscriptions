# frozen_string_literal: true

module EventStoreSubscriptions
  # This class is used to persist and update the revision when subscribing to the specific stream.
  # Specific streams are streams which names differ from "$all".
  class SubscriptionRevision < Struct.new(:revision)
    attr_reader :update_hooks

    def initialize(*)
      super
      @update_hooks = []
    end

    # Updates the revision from GRPC response.
    # @param response [EventStore::Client::Streams::ReadResp] GRPC EventStore object. See its
    #   structure in the lib/event_store_client/adapters/grpc/generated/streams_pb.rb file in
    #   `event_store_client` gem.
    # @return [Boolean] whether the revision was updated
    def update(response)
      return false unless response.event&.event

      # Updating revision value in memory first to prevent the situation when update hook fails and,
      # thus keeping the revision not up to date
      self.revision = response.event.event.stream_revision
      update_hooks.each do |handler|
        handler.call(self)
      end
      true
    end

    # Adds a handler that will be executed when the revision gets updates. You may add as many
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

    # Checks if revision property is absent
    # @return [Boolean]
    def empty?
      revision.nil?
    end

    # Checks if revision property is set
    # @return [Boolean]
    def present?
      !empty?
    end

    # Constructs a hash compatible for usage with EventStoreClient::GRPC::Client#subscribe_to_stream
    # method. You can pass it into :options keyword argument of that method to set the starting
    # revision of the stream.
    # @return [Hash]
    def to_option
      { from_revision: revision }
    end
  end
end
