# frozen_string_literal: true

module EventStoreSubscriptions
  # Watches over the given Subscriptions collection and restarts dead Subscription-s. It is useful
  # in cases when your Subscription's handler raises error. Its usage is optional.
  class WatchDog
    include WaitForFinish

    class << self
      # @param collection [EventStoreSubscriptions::Subscriptions]
      # @return [EventStoreSubscriptions::WatchDog]
      def watch(collection)
        new(collection).watch
      end
    end

    attr_accessor :runner
    attr_reader :collection, :state
    private :collection, :runner, :runner=, :state

    # @param collection [EventStoreSubscriptions::Subscriptions]
    def initialize(collection)
      @collection = collection
      @state = ObjectState.new
      @runner = nil
    end

    # Start watching over the given Subscriptions collection
    # @return [EventStoreSubscriptions::WatchDog] returns self
    def watch
      self.runner ||=
        Thread.new do
          state.running!
          loop do
            sleep 1
            break unless state.running?

            collection.subscriptions.each do |sub|
              break unless state.running?

              restart_subscription(sub) if sub.state.dead?
            end
          end
        end
      self
    end

    # Stop watching over the given Subscriptions collection. This command is async - the result is
    # not immediate. In order to wait for the runner fully stopped - use #wait_for_finish method.
    # Example:
    #   ```ruby
    #   watch_dog.unwatch.wait_for_finish
    #   ```
    # @return [EventStoreSubscriptions::WatchDog] returns self
    def unwatch
      return self unless runner&.alive?

      state.halting!
      Thread.new do
        loop do
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

    private

    # @param old_sub [EventStoreSubscriptions::Subscription]
    # @return [EventStoreSubscriptions::Subscription] newly created Subscription
    def restart_subscription(old_sub)
      # Check if no one else did this job
      return unless collection.remove(old_sub)

      new_sub = Subscription.new(
        position: old_sub.position,
        client: old_sub.client,
        setup: old_sub.setup,
        statistic: old_sub.statistic
      )
      new_sub.statistic.last_restart_at = Time.now.utc
      collection.add(new_sub)
      old_sub.delete
      new_sub.listen
    end
  end
end
