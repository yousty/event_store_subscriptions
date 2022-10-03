# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::SubscriptionStatistic do
  subject { instance }

  let(:instance) { described_class.new }

  it { is_expected.to respond_to(:last_error) }
  it { is_expected.to respond_to(:last_error=) }
  it { is_expected.to respond_to(:errors_count) }
  it { is_expected.to respond_to(:errors_count=) }
  it { is_expected.to respond_to(:events_processed) }
  it { is_expected.to respond_to(:events_processed=) }
  it { is_expected.to respond_to(:last_restart_at) }
  it { is_expected.to respond_to(:last_restart_at=) }
end
