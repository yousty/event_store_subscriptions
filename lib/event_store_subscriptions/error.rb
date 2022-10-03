# frozen_string_literal: true

module EventStoreSubscriptions
  class Error < StandardError
  end

  class ThreadNotDeadError < Error
  end
end
