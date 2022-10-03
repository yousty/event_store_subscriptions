# frozen_string_literal: true

require 'benchmark'

RSpec.describe EventStoreSubscriptions::WaitForFinish do
  let(:dummy_class) do
    klass = Class.new do
      attr_reader :state

      def initialize
        @state = EventStoreSubscriptions::ObjectState.new
      end
    end
    klass.tap do |c|
      c.include described_class
    end
  end
  let(:instance) { dummy_class.new }

  describe '#wait_for_finish' do
    subject { instance.wait_for_finish }

    context 'when state is :dead' do
      before do
        instance.state.dead!
      end

      it 'stops waiting' do
        is_expected.to be_nil
      end
    end

    context 'when state is :stopped' do
      before do
        instance.state.stopped!
      end

      it 'stops waiting' do
        is_expected.to be_nil
      end
    end

    context 'when state is something else' do
      it 'waits when state turns to :stopped or :dead' do
        thread = Thread.new do
          sleep 0.5
          instance.state.stopped!
        end
        time_waited = Benchmark.measure { subject }.real
        thread.exit
        expect(time_waited).to be > 0.5
      end
    end
  end
end
