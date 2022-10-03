# frozen_string_literal: true

module EventStoreSubscriptions
  # Handles arguments that were used to create a subscription. We need to persist them for
  # later adjustment and delegation.
  class SubscriptionSetup < Struct.new(:args, :kwargs, :blk)
    # @return [EventStoreSubscriptions::SubscriptionSetup]
    def dup
      self.class.new(args.dup, deep_dup(kwargs), blk)
    end

    private

    # @param hash [Hash]
    # @return [Hash]
    def deep_dup(hash)
      result = {}
      hash.each_pair do |k, v|
        result[k] =
          case v
          when Hash
            deep_dup(v)
          when Array
            v.dup
          else
            v
          end
      end
      result
    end
  end
end
