# frozen_string_literal: true

module EventStoreSubscriptions
  class SubscriptionStatistic
    attr_accessor :last_error, :errors_count, :events_processed, :last_restart_at

    def initialize
      @last_error = nil
      @last_restart_at = nil
      @errors_count = 0
      @events_processed = 0
    end
  end
end
