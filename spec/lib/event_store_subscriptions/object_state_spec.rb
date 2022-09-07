# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::ObjectState do
  let(:instance) { described_class.new }

  shared_examples 'in the appropriate state' do
    context 'when object is in the given state' do
      before do
        instance.public_send("#{state}!")
      end

      it { is_expected.to be_truthy }
    end

    context 'when object is in another state' do
      before do
        another_state = state == :dead ? :stopped : :dead
        instance.public_send("#{another_state}!")
      end

      it { is_expected.to eq(false) }
    end
  end

  shared_examples 'sets the state' do
    it 'changes the state' do
      expect { subject }.to change { instance.send(:state) }.to(state)
    end
  end

  describe 'constants' do
    describe 'STATES' do
      subject { described_class::STATES }

      it { is_expected.to eq(%i(initial running halting stopped dead)) }
      it { is_expected.to be_frozen }
    end
  end

  describe '#initial?' do
    subject { instance.initial? }

    it_behaves_like 'in the appropriate state' do
      let(:state) { :initial }
    end

    it 'is in the :initial state by default' do
      is_expected.to be_truthy
    end
  end

  describe '#running?' do
    subject { instance.running? }

    it_behaves_like 'in the appropriate state' do
      let(:state) { :running }
    end
  end

  describe '#halting?' do
    subject { instance.halting? }

    it_behaves_like 'in the appropriate state' do
      let(:state) { :halting }
    end
  end

  describe '#stopped?' do
    subject { instance.stopped? }

    it_behaves_like 'in the appropriate state' do
      let(:state) { :stopped }
    end
  end

  describe '#dead?' do
    subject { instance.dead? }

    it_behaves_like 'in the appropriate state' do
      let(:state) { :dead }
    end
  end

  describe '#initial!' do
    subject { instance.initial! }

    before do
      instance.dead!
    end

    it_behaves_like 'sets the state' do
      let(:state) { :initial }
    end
  end

  describe '#running!' do
    subject { instance.running! }

    it_behaves_like 'sets the state' do
      let(:state) { :running }
    end
  end

  describe '#halting!' do
    subject { instance.halting! }

    it_behaves_like 'sets the state' do
      let(:state) { :halting }
    end
  end

  describe '#stopped!' do
    subject { instance.stopped! }

    it_behaves_like 'sets the state' do
      let(:state) { :stopped }
    end
  end

  describe '#dead!' do
    subject { instance.dead! }

    it_behaves_like 'sets the state' do
      let(:state) { :dead }
    end
  end

  describe '#to_s' do
    subject { instance.to_s }

    it 'returns string representation of current state' do
      is_expected.to eq('initial')
    end
  end
end
