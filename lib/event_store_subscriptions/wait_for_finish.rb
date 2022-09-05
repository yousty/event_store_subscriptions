# frozen_string_literal: true

module EventStoreSubscriptions
  module WaitForFinish
    # Waits until state switches from :running to any other state.
    # @return [void]
    def wait_for_finish
      loop do
        break if state.stopped? || state.dead?

        sleep 0.1
      end
    end
  end
end
