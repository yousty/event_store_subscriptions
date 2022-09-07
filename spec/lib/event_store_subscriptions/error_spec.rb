# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::Error do
  it { is_expected.to be_a(StandardError) }

  describe 'children' do
    describe 'ThreadNotDeadError' do
      subject { EventStoreSubscriptions::ThreadNotDeadError }

      it { is_expected.to be < described_class }
    end
  end
end
