# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::Subscriptions do
  let(:instance) { described_class.new(client) }
  let(:client) { EventStoreClient.client }

  describe 'constants' do
    describe 'ALL_STREAM' do
      subject { described_class::ALL_STREAM }

      it { is_expected.to eq('$all') }
      it { is_expected.to be_frozen }
    end
  end

  describe '#create' do
    subject { instance.create(*args, **kwargs, &blk) }

    let(:args) { ['$all'] }
    let(:kwargs) { { handler: proc { }, options: { from_position: { commit_position: 0 } } } }
    let(:blk) { proc { } }

    it 'returns newly created Subscription' do
      is_expected.to be_a(EventStoreSubscriptions::Subscription)
    end
    it 'adds Subscription to the collection' do
      expect { subject }.to change { instance.subscriptions.size }.by(1)
    end

    describe 'created Subscription' do
      it 'has correct client' do
        expect(subject.client).to eq(client)
      end
      it 'has correct setup' do
        aggregate_failures do
          expect(subject.setup.args).to eq(args)
          expect(subject.setup.kwargs).to eq(kwargs)
          expect(subject.setup.blk).to eq(blk)
        end
      end

      context 'when stream name is "$all"' do
        it 'has correct position class' do
          expect(subject.position).to be_a(EventStoreSubscriptions::SubscriptionPosition)
        end
      end

      context 'when stream name is a specific stream' do
        let(:args) { ['some-stream'] }

        it 'has correct position class' do
          expect(subject.position).to be_a(EventStoreSubscriptions::SubscriptionRevision)
        end
      end
    end
  end

  describe '#create_for_all' do
    subject { instance.create_for_all(**kwargs, &blk) }

    let(:kwargs) { { handler: proc { } } }
    let(:blk) { proc { } }

    before do
      allow(instance).to receive(:create).and_call_original
    end

    it 'creates Subscription for "$all" stream' do
      subject
      expect(instance).to have_received(:create).with('$all', **kwargs, &blk)
    end
  end

  describe '#add' do
    subject { instance.add(subscription) }

    let(:subscription) { EventStoreSubscriptions::Subscription.allocate }

    it 'adds Subscription to collection' do
      expect { subject }.to change { instance.subscriptions.size }.by(1)
    end
    it 'returns current collection' do
      is_expected.to eq([subscription])
    end
  end

  describe '#remove' do
    subject { instance.remove(subscription) }

    let(:subscription) { EventStoreSubscriptions::Subscription.allocate }

    before do
      instance.add(subscription)
    end

    it 'removes Subscription for collection' do
      expect { subject }.to change { instance.subscriptions.size }.by(-1)
    end
    it 'returns removed Subscription' do
      is_expected.to eq(subscription)
    end
  end

  describe '#listen_all' do
    subject { instance.listen_all }

    let(:subscription_1) { EventStoreSubscriptions::Subscription.allocate }
    let(:subscription_2) { EventStoreSubscriptions::Subscription.allocate }

    before do
      instance.add(subscription_1)
      instance.add(subscription_2)
      allow(subscription_1).to receive(:listen)
      allow(subscription_2).to receive(:listen)
    end

    it 'starts listening all Subscriptions in collection' do
      subject
      aggregate_failures do
        expect(subscription_1).to have_received(:listen)
        expect(subscription_2).to have_received(:listen)
      end
    end
    it 'returns all Subscriptions in collection' do
      is_expected.to eq([subscription_1, subscription_2])
    end
  end

  describe '#stop_all' do
    subject { instance.stop_all }

    let(:subscription_1) { EventStoreSubscriptions::Subscription.allocate }
    let(:subscription_2) { EventStoreSubscriptions::Subscription.allocate }

    before do
      instance.add(subscription_1)
      instance.add(subscription_2)
      allow(subscription_1).to receive(:stop_listening)
      allow(subscription_2).to receive(:stop_listening)
    end

    it 'stops listening all Subscriptions in collection' do
      subject
      aggregate_failures do
        expect(subscription_1).to have_received(:stop_listening)
        expect(subscription_2).to have_received(:stop_listening)
      end
    end
    it 'returns all Subscriptions in collection' do
      is_expected.to eq([subscription_1, subscription_2])
    end
  end

  describe '#subscriptions' do
    subject { instance.subscriptions }

    let(:subscription_1) { EventStoreSubscriptions::Subscription.allocate }
    let(:subscription_2) { EventStoreSubscriptions::Subscription.allocate }

    before do
      instance.add(subscription_1)
      instance.add(subscription_2)
    end

    it 'returns all Subscriptions in collection' do
      is_expected.to eq([subscription_1, subscription_2])
    end
    it 'dups the original collection' do
      expect(subject.__id__).not_to eq(instance.instance_variable_get(:@subscriptions).__id__)
    end
  end
end
