# frozen_string_literal: true

RSpec.describe EventStoreSubscriptions::Subscription do
  subject { instance }

  let(:instance) { described_class.new(position: position, client: client, setup: setup) }
  let(:position) { EventStoreSubscriptions::SubscriptionPosition.new }
  let(:client) { EventStoreClient.client }
  let(:setup) do
    EventStoreSubscriptions::SubscriptionSetup.new(['$all'], { options: options, handler: handler })
  end
  let(:options) { {} }
  let(:handler) { proc { } }

  it { is_expected.to be_a(EventStoreSubscriptions::WaitForFinish) }

  describe 'constants' do
    describe 'FORCED_SHUTDOWN_DELAY' do
      subject { described_class::FORCED_SHUTDOWN_DELAY }

      it { is_expected.to eq(60) }
    end
  end

  describe '#listen' do
    subject { instance.listen }

    before do
      stub_const('EventStoreSubscriptions::Subscription::FORCED_SHUTDOWN_DELAY', 0)
    end

    after do
      instance.stop_listening.wait_for_finish
    end

    it 'returns self' do
      is_expected.to eq(instance)
    end
    it 'starts events listening' do
      expect { subject }.to change { instance.state.send(:state) }.to(:running)
    end

    context 'when error raises in the runner' do
      let(:error) { StandardError.new('network error') }

      before do
        allow(client).to receive(:subscribe_to_stream).and_raise(error)
      end

      it 'changes the state to :dead' do
        expect { subject; sleep 0.2 }.to change { instance.state.send(:state) }.to(:dead)
      end
      it 'persists the error into the statistic' do
        expect { subject; sleep 0.2 }.to change { instance.statistic.last_error }.to(error)
      end
      it 'increments errors counter' do
        expect { subject; sleep 0.2 }.to change { instance.statistic.errors_count }.by(1)
      end
    end
  end

  describe '#stop_listening' do
    subject { instance.stop_listening }

    before do
      stub_const('EventStoreSubscriptions::Subscription::FORCED_SHUTDOWN_DELAY', 0)
    end

    context 'when runner is alive' do
      before do
        instance.listen
      end

      after do
        instance.wait_for_finish
      end

      it 'returns self' do
        is_expected.to eq(instance)
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

    context 'when runner is not alive' do
      let(:runner) { Thread.new { }.join }

      before do
        allow(runner).to receive(:exit).and_call_original
        instance.instance_variable_set(:@runner, runner)
      end

      it 'returns self' do
        is_expected.to eq(instance)
      end
      it 'does not change state' do
        expect { subject }.not_to change { instance.state.send(:state) }
      end
      it 'does not shutdown runner' do
        subject
        sleep 0.2
        expect(runner).not_to have_received(:exit)
      end
      it 'does not unassigns runner' do
        expect { subject; sleep 0.2 }.not_to change { instance.send(:runner) }
      end
    end
  end

  describe '#restart' do
    subject { instance.restart }

    before do
      stub_const('EventStoreSubscriptions::Subscription::FORCED_SHUTDOWN_DELAY', 0)
      instance.state.dead!
    end

    after do
      instance.stop_listening.wait_for_finish
    end

    it 'restarts it' do
      expect { subject; sleep 0.2 }.to change { instance.state.send(:state) }.to(:running)
    end
    it 'updates #last_restart_at of the subscription' do
      expect { subject; sleep 0.2 }.to change {
        instance.statistic.last_restart_at
      }.to(be_between(Time.now, Time.now + 0.3))
    end
    it 'reassigns #runner' do
      expect { subject; sleep 0.2 }.to change { instance.send(:runner).__id__ }
    end
  end

  describe 'integration' do
    subject do
      client.append_to_stream(stream_name, EventStoreClient::DeserializedEvent.new)
    end

    let(:setup) do
      EventStoreSubscriptions::SubscriptionSetup.new(['$all'], kwargs)
    end
    let(:kwargs) do
      { options: options, handler: handler }
    end
    let(:options) { { filter: { stream_identifier: { prefix: [stream_name] } } } }
    let(:stream_name) { "some-stream$#{SecureRandom.uuid}" }
    let(:handler) { proc { |resp| responses.push(resp) } }
    let(:responses) { [] }

    before do
      stub_const('EventStoreSubscriptions::Subscription::FORCED_SHUTDOWN_DELAY', 0)
    end

    describe 'events processing' do
      before do
        instance.listen
        sleep 0.5
      end

      after do
        instance.stop_listening.wait_for_finish
      end

      it 'processes events using provided handler' do
        expect {
          subject
          sleep 0.2
        }.to change { responses.size }.by(1)
      end
      it 'updates Subscription position' do
        expect {
          subject
          sleep 0.2
        }.to change { instance.position }
      end
      it 'updates number of processed events' do
        expect {
          subject
          sleep 0.2
        }.to change { instance.statistic.events_processed }.by(1)
      end

      describe 'received response' do
        subject { responses.first }

        before do
          client.append_to_stream(stream_name, EventStoreClient::DeserializedEvent.new)
          sleep 0.5
        end

        it { is_expected.to be_a(Dry::Monads::Success) }
        it 'belongs to correct stream' do
          expect(subject.success.stream_name).to eq(stream_name)
        end
      end
    end

    context 'when SubscriptionPosition is present' do
      let(:options) do
        {
          filter: { stream_identifier: { prefix: [stream_name] } },
          from_position: { commit_position: 0 }
        }
      end

      before do
        # Generate an event and get the position of it
        position =
          EventStoreClient.client.append_to_stream(
            stream_name, EventStoreClient::DeserializedEvent.new
          ).success.success.position
        instance.position.commit_position = position.commit_position
        instance.position.prepare_position = position.prepare_position
        # Generate another event for another stream. It will help us to ensure that the given
        # SubscriptionPosition does not break other options. E.g. if to break :filter option - this
        # event will pop up in the result
        EventStoreClient.client.append_to_stream(
          "some-another-stream$#{SecureRandom.uuid}",
          EventStoreClient::DeserializedEvent.new
        )
      end

      after do
        instance.stop_listening.wait_for_finish
      end

      it 'skips events before current position' do
        expect {
          instance.listen
          sleep 0.5
          subject
          sleep 0.2
        }.to change { responses.size }.by(1)
      end
    end
  end
end
