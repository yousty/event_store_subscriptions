# frozen_string_literal: true

module EventStoreSubscriptions
  # Implements Subscription-s collection
  class Subscriptions
    attr_reader :client
    attr_reader :semaphore
    private :semaphore

    # @param client [EventStoreClient::GRPC::Client]
    def initialize(client)
      @client = client
      @subscriptions = []
      @semaphore = Mutex.new
    end

    # @see EventStoreClient::GRPC::Client#subscribe_to_stream documentation for available params
    # @return [EventStoreSubscriptions::Subscription]
    def create(*args, **kwargs, &blk)
      setup = SubscriptionSetup.new(args, kwargs, blk)
      subscription = Subscription.new(
        position: position_class(args[0]).new, client: client, setup: setup
      )
      add(subscription)
      subscription
    end

    # Shortcut to create a Subscription to subscribe to the '$all' stream
    # @see EventStoreClient::GRPC::Client#subscribe_to_all documentation for available params
    # @return [EventStoreSubscriptions::Subscription]
    def create_for_all(**kwargs, &blk)
      create('$all', **kwargs, &blk)
    end

    # Adds Subscription to the collection
    # @param subscription [EventStoreSubscriptions::Subscription]
    # @return [Array<EventStoreSubscriptions::Subscription>] current subscription's collection
    def add(subscription)
      semaphore.synchronize { @subscriptions << subscription }
    end

    # Removes subscription from the collection
    # @param subscription [EventStoreSubscriptions::Subscription]
    # @return [EventStoreSubscriptions::Subscription, nil] returns deleted subscription or nil if it
    #   wasn't present in the collection
    def remove(subscription)
      semaphore.synchronize { @subscriptions.delete(subscription) }
    end

    # Starts listening to all subscriptions in the collection
    # @return [Array<EventStoreSubscriptions::Subscription>]
    def listen_all
      semaphore.synchronize { @subscriptions.each(&:listen) }
    end

    # Stops listening to all subscriptions in the collection
    # @return [Array<EventStoreSubscriptions::Subscription>]
    def stop_all
      semaphore.synchronize { @subscriptions.each(&:stop_listening) }
    end

    # @return [Array<EventStoreSubscriptions::Subscription>]
    def subscriptions
      # Duping original collection to prevent potential mutable operations over it from user's side
      semaphore.synchronize { @subscriptions.dup }
    end

    private

    # @param stream_name [String]
    # @return [Class<EventStoreSubscriptions::SubscriptionPosition>, Class<EventStoreSubscriptions::SubscriptionRevision>]
    def position_class(stream_name)
      stream_name == '$all' ? SubscriptionPosition : SubscriptionRevision
    end
  end
end
