# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::SubscriptionSetup do
  subject { instance }

  let(:instance) { described_class.new(args, kwargs, blk) }
  let(:args) { ['$all'] }
  let(:kwargs) do
    {
      handler: proc { },
      options: {
        from_revision: 1,
        filter: { stream_identifier: { prefix: ['some-stream'] } }
      }
    }
  end
  let(:blk) { proc { } }

  it { is_expected.to be_a(Struct) }

  describe '#dup' do
    subject { instance.dup }

    it { is_expected.to be_a(described_class) }
    it 'has the same args' do
      expect(subject.args).to eq(args)
    end
    it 'has the same kwargs' do
      expect(subject.kwargs).to eq(kwargs)
    end
    it 'has the same blk' do
      expect(subject.blk).to eq(blk)
    end
    it 'duplicates args' do
      expect(subject.args.__id__).not_to eq(instance.args.__id__)
    end
    it 'duplicates kwargs' do
      expect(subject.kwargs.__id__).not_to eq(instance.kwargs.__id__)
    end
    it 'duplicates kwargs sub-hashes' do
      expect(subject.kwargs[:options].__id__).not_to eq(instance.kwargs[:options].__id__)
    end
    it 'duplicates kwargs sub-arrays' do
      path = [:options, :filter, :stream_identifier, :prefix]
      expect(subject.kwargs.dig(*path).__id__).not_to eq(instance.kwargs.dig(*path).__id__)
    end
  end
end
