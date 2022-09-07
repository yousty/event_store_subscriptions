# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::SubscriptionPosition do
  subject { instance }

  let(:instance) { described_class.new }

  it { is_expected.to be_a(Struct) }

  describe '#update' do
    subject { instance.update(response) }

    let(:response) do
      EventStore::Client::Streams::ReadResp.new(
        checkpoint:
          EventStore::Client::Streams::ReadResp::Checkpoint.new(
            commit_position: commit_position,
            prepare_position: prepare_position
          )
      )
    end
    let(:commit_position) { 1_023 }
    let(:prepare_position) { 0 }
    let(:handler) { proc { |position| positions.push(position) } }
    let(:positions) { [] }

    before do
      instance.register_update_hook(&handler)
    end

    shared_examples 'processes response' do
      it 'updates commit_position' do
        expect { subject }.to change { instance.commit_position }.to(commit_position)
      end
      it 'updates prepare_position' do
        expect { subject }.to change { instance.prepare_position }.to(prepare_position)
      end
      it { is_expected.to be_truthy }
      it 'executes registered update hooks' do
        expect { subject }.to change { positions.size }.by(1)
      end
    end

    context 'when response is a checkpoint' do
      it_behaves_like 'processes response'
    end

    context 'when response is an event' do
      let(:response) do
        EventStore::Client::Streams::ReadResp.new(
          event: EventStore::Client::Streams::ReadResp::ReadEvent.new(
            event: EventStore::Client::Streams::ReadResp::ReadEvent::RecordedEvent.new(
              commit_position: commit_position,
              prepare_position: prepare_position
            )
          )
        )
      end

      it_behaves_like 'processes response'
    end

    context 'when response is something else' do
      let(:response) do
        EventStore::Client::Streams::ReadResp.new(
          confirmation: EventStore::Client::Streams::ReadResp::SubscriptionConfirmation.new
        )
      end

      it { is_expected.to eq(false) }
      it 'does not update positions' do
        expect { subject }.not_to change { instance }
      end
      it 'does not execute registered update hooks' do
        expect { subject }.not_to change { positions.size }
      end
    end
  end

  describe '#register_update_hook' do
    subject { instance.register_update_hook(&hook) }

    let(:hook) { proc { } }

    it 'registers update hook' do
      expect { subject }.to change { instance.update_hooks }.to([hook])
    end
  end

  describe '#empty?' do
    subject { instance.empty? }

    context 'when only commit_position is present ' do
      before do
        instance.commit_position = 1
      end

      it { is_expected.to eq(true) }
    end

    context 'when only prepare_position is present' do
      before do
        instance.prepare_position = 1
      end

      it { is_expected.to eq(true) }
    end

    context 'no position is present' do
      it { is_expected.to eq(true) }
    end

    context 'when both positions are present' do
      before do
        instance.commit_position = 1
        instance.prepare_position = 0
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#present?' do
    subject { instance.present? }

    context 'when only commit_position is present ' do
      before do
        instance.commit_position = 1
      end

      it { is_expected.to eq(false) }
    end

    context 'when only prepare_position is present' do
      before do
        instance.prepare_position = 1
      end

      it { is_expected.to eq(false) }
    end

    context 'no position is present' do
      it { is_expected.to eq(false) }
    end

    context 'when both positions are present' do
      before do
        instance.commit_position = 1
        instance.prepare_position = 0
      end

      it { is_expected.to eq(true) }
    end
  end

  describe '#to_option' do
    subject { instance.to_option }

    before do
      instance.commit_position = 1
      instance.prepare_position = 0
    end

    it 'returns EventStoreClient compatible hash' do
      is_expected.to(
        eq(
          from_position: {
            commit_position: instance.commit_position, prepare_position: instance.prepare_position
          }
        )
      )
    end
  end
end
