# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::SubscriptionRevision do
  subject { instance }

  let(:instance) { described_class.new }

  it { is_expected.to be_a(Struct) }

  describe '#update' do
    subject { instance.update(response) }

    let(:response) do
      EventStore::Client::Streams::ReadResp.new(
        event: EventStore::Client::Streams::ReadResp::ReadEvent.new(
          event: EventStore::Client::Streams::ReadResp::ReadEvent::RecordedEvent.new(
            stream_revision: revision
          )
        )
      )
    end
    let(:revision) { 2 }
    let(:handler) { proc { |position| positions.push(position) } }
    let(:positions) { [] }

    before do
      instance.register_update_hook(&handler)
    end

    context 'when response is an event' do
      it 'updates revision' do
        expect { subject }.to change { instance.revision }.to(revision)
      end
      it { is_expected.to be_truthy }
      it 'executes registered update hooks' do
        expect { subject }.to change { positions.size }.by(1)
      end

      context 'when handler raises error' do
        let(:handler) { proc { raise error } }
        let(:error) { Class.new(StandardError) }

        it 'raises that error' do
          expect { subject }.to raise_error(error)
        end
        it 'updates revision' do
          expect { subject rescue nil }.to change { instance.revision }.to(revision)
        end
      end
    end

    context 'when response is something else' do
      let(:response) do
        EventStore::Client::Streams::ReadResp.new(
          confirmation: EventStore::Client::Streams::ReadResp::SubscriptionConfirmation.new
        )
      end

      it { is_expected.to eq(false) }
      it 'does not update revision' do
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

    context 'when revision is present ' do
      before do
        instance.revision = 1
      end

      it { is_expected.to eq(false) }
    end

    context 'when revision is absent' do
      it { is_expected.to eq(true) }
    end
  end

  describe '#present?' do
    subject { instance.present? }

    context 'when revision is present ' do
      before do
        instance.revision = 1
      end

      it { is_expected.to eq(true) }
    end

    context 'when revision is absent' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#to_option' do
    subject { instance.to_option }

    before do
      instance.revision = 1
    end

    it 'returns EventStoreClient compatible hash' do
      is_expected.to eq(from_revision: instance.revision)
    end
  end
end
