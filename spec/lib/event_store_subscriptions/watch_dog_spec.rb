# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::WatchDog do
  subject { instance }

  let(:instance) { described_class.new(collection) }
  let(:collection) { EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client) }

  it { is_expected.to be_a(EventStoreSubscriptions::WaitForFinish) }

  describe 'constants' do
    describe 'CHECK_INTERVAL' do
      subject { described_class::CHECK_INTERVAL }

      before do

      end

      it { is_expected.to eq(5) }
    end
  end

  describe '.watch' do
    subject { described_class.watch(collection) }

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
  end

  describe '#watch' do
    subject { instance.watch }

    let(:subscription) { collection.create_for_all(handler: proc { }) }

    before do
      stub_const("#{described_class}::CHECK_INTERVAL", 0.1)
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
      before do
        subscription.state.dead!
      end

      it 'restarts it' do
        expect { subject; sleep 0.2 }.to change { collection.subscriptions.first.__id__ }
      end
      it 'does not keep old one' do
        expect { subject; sleep 0.2 }.not_to change { collection.subscriptions.size }
      end

      describe 'restarted Subscription' do
        subject { super(); sleep 0.2; collection.subscriptions.first }

        let!(:position) { subscription.position }
        let!(:client) { subscription.client }
        let!(:setup) { subscription.setup }
        let!(:statistic) { subscription.statistic }

        it 'is another object' do
          expect(subject.__id__).not_to eq(subscription.__id__)
        end
        it 'has the same SubscriptionPosition' do
          expect(subject.position.__id__).to eq(position.__id__)
        end
        it 'has the same client' do
          expect(subject.client.__id__).to eq(client.__id__)
        end
        it 'has the same SubscriptionSetup' do
          expect(subject.setup.__id__).to eq(setup.__id__)
        end
        it 'has the SubscriptionStatistic' do
          expect(subject.statistic.__id__).to eq(statistic.__id__)
        end
        it 'deletes old subscription' do
          subject
          expect(subscription).to be_frozen
        end
        it 'sets #last_restart_at of the statistic' do
          subject
          expect(subject.statistic.last_restart_at).to be_between(Time.now - 2, Time.now)
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
