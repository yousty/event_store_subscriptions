# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::WatchDog do
  subject { instance }

  let(:instance) { described_class.new(collection, restart_terminator: restart_terminator) }
  let(:collection) { EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client) }
  let(:restart_terminator) { nil }

  it { is_expected.to be_a(EventStoreSubscriptions::WaitForFinish) }

  describe 'constants' do
    describe 'CHECK_INTERVAL' do
      subject { described_class::CHECK_INTERVAL }

      it { is_expected.to eq(5) }
    end
  end

  describe '.watch' do
    subject { described_class.watch(collection, restart_terminator: restart_terminator) }

    let(:restart_terminator) { proc { } }

    before do
      allow(described_class).to receive(:new).and_wrap_original do |original_method, *args, **kwargs, &blk|
        instance = original_method.call(*args, **kwargs, &blk)
        allow(instance).to receive(:watch).and_call_original
        instance
      end
    end

    after do
      subject.unwatch.wait_for_finish
    end

    it { is_expected.to be_a(described_class) }
    it 'starts watching after the given collection' do
      expect(subject).to have_received(:watch)
    end
    it 'has correct restart_terminator' do
      expect(subject.send(:restart_terminator)).to eq(restart_terminator)
    end
  end

  describe '#watch' do
    subject { instance.watch }

    before do
      stub_const("#{described_class}::CHECK_INTERVAL", 0.1)
      stub_const("EventStoreSubscriptions::Subscription::FORCED_SHUTDOWN_DELAY", 0.1)
    end

    after do
      instance.unwatch.wait_for_finish
    end

    it 'changes state to :running' do
      expect { subject }.to change { instance.state.send(:state) }.to(:running)
    end

    context 'when state switches from :running' do
      it 'stops runner' do
        subject
        instance.state.stopped!
        sleep 0.2
        expect(instance.send(:runner)).not_to be_alive
      end
    end

    context 'when Subscription dies' do
      let(:subscription) { collection.create_for_all(handler: proc { }) }

      before do
        allow(subscription).to receive(:restart).and_call_original
        subscription.state.dead!
      end

      after do
        subscription.stop_listening.wait_for_finish
      end

      it 'restarts it' do
        subject
        sleep 0.2
        expect(subscription).to have_received(:restart)
      end

      context 'when restart terminator is given' do
        let(:restart_terminator) { :itself.to_proc }

        context 'when it returns truthy result' do
          it 'does not restart the subscription' do
            subject
            sleep 0.2
            expect(subscription).not_to have_received(:restart)
          end
        end

        context 'when it returns falsey result' do
          let(:restart_terminator) { nil }

          it 'restarts it' do
            subject
            sleep 0.2
            expect(subscription).to have_received(:restart)
          end
        end
      end
    end
  end

  describe '#unwatch' do
    subject { instance.unwatch }

    before do
      stub_const("#{described_class}::CHECK_INTERVAL", 0.1)
      instance.watch
      sleep 0.2
    end

    after do
      instance.wait_for_finish
    end

    it 'changes state to :halting' do
      expect { subject }.to change { instance.state.send(:state) }.to(:halting)
    end
    it 'changes state to :stopped eventually' do
      expect { subject; sleep 0.2 }.to change { instance.state.send(:state) }.to(:stopped)
    end
    it 'terminates the runner' do
      runner = instance.send(:runner)
      expect { subject; sleep 0.2 }.to change { runner.alive? }.to(false)
    end
    it 'unassigns runner' do
      expect { subject; sleep 0.2 }.to change { instance.send(:runner) }.to(nil)
    end
  end
end
