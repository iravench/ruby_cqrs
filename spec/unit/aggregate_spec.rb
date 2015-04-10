require_relative('../spec_helper')

describe RubyCqrs::Domain::Aggregate do
  let(:aggregate_id) { SomeDomain::AGGREGATE_ID }
  let(:aggregate_root) { SomeDomain::AggregateRoot.new }

  describe '#new' do
    it 'has aggregate_id initilized as a valid uuid' do
      expect(aggregate_root.aggregate_id).to be_a_valid_uuid
    end

    it 'has version initilized as 0' do
      expect(aggregate_root.version).to be_zero
    end

    it 'has source_version initilized as 0' do
      expect(aggregate_root.instance_variable_get(:@source_version)).to be_zero
    end
  end

  describe '#raise_event' do
    it 'raise NotADomainEventError when raising an object that is not a proper event' do
      expect { aggregate_root.fire_weird_stuff }.to raise_error(RubyCqrs::NotADomainEventError)
    end

    context 'after raising an event' do
      it 'has version increased by 1' do
        original_version = aggregate_root.version
        aggregate_root.test_fire

        expect(aggregate_root.version).to eq(original_version + 1)
      end

      it 'leaves source_version unchanged' do
        original_source_version = aggregate_root.instance_variable_get(:@source_version)
        aggregate_root.test_fire

        expect(aggregate_root.instance_variable_get(:@source_version)).to eq original_source_version
      end

      it 'calls #on_third_event' do
        expect(aggregate_root).to receive(:on_third_event)
        aggregate_root.test_fire
      end
    end
  end

  describe '#is_version_conflicted?' do
    let(:unsorted_events) { SomeDomain::UNSORTED_EVENTS }
    let(:state) { { :aggregate_id => aggregate_id, :events => unsorted_events } }
    let(:loaded_aggregate) { aggregate_root.send(:load_from, state); aggregate_root; }

    it 'returns true when supplied client side version does not match the server side persisted source_version' do
      client_side_version = unsorted_events.size - 1
      expect(loaded_aggregate.is_version_conflicted? client_side_version).to be_truthy
    end

    it 'returns false when supplied client side version matches the server side persisted source_version' do
      client_side_version = unsorted_events.size
      expect(loaded_aggregate.is_version_conflicted? client_side_version).to be_falsy
    end
  end

  describe '#get_changes' do
    context 'after raising no event' do
      it 'returns nil' do
        expect(aggregate_root.send(:get_changes)).to be_nil
      end
    end

    context 'after raising 2 events' do
      it 'returns proper change summary' do
        aggregate_root.test_fire
        aggregate_root.test_fire_ag
        pending_changes = aggregate_root.send(:get_changes)

        expect(pending_changes[:events].size).to eq(2)
        expect(pending_changes[:events][0].version).to eq(1)
        expect(pending_changes[:events][1].version).to eq(2)
        expect(pending_changes[:aggregate_id]).to eq(aggregate_root.aggregate_id)
        expect(pending_changes[:aggregate_type]).to eq(aggregate_root.class.name)
        expect(pending_changes[:expecting_source_version]).to eq(0)
        expect(pending_changes[:expecting_version]).to eq(2)
      end
    end
  end

  describe '#load_from' do
    let(:unsorted_events) { SomeDomain::UNSORTED_EVENTS }
    let(:state) { { :aggregate_id => aggregate_id, :events => unsorted_events } }
    let(:loaded_aggregate) { aggregate_root.send(:load_from, state); aggregate_root; }

    context 'when loading events' do
      after(:each) { aggregate_root.send(:load_from, state) }

      it 'calls #on_first_event' do
        expect(aggregate_root).to receive(:on_first_event)
      end

      it 'calls #on_second_event' do
        expect(aggregate_root).to receive(:on_second_event)
      end

      it 'calls #on_first_event, #on_second_event in order' do
        expect(aggregate_root).to receive(:on_first_event).ordered
        expect(aggregate_root).to receive(:on_second_event).ordered
      end
    end

    context 'after events are loaded' do
      it "has aggregate_id set to the events' aggregate_id" do
        expect(loaded_aggregate.aggregate_id).to eq(aggregate_id)
      end

      it 'has version set to the number of loaded events' do
        expect(loaded_aggregate.version).to eq(unsorted_events.size)
      end

      it 'has source_version set to the number of loaded events' do
        expect(loaded_aggregate.instance_variable_get(:@source_version)).to eq(unsorted_events.size)
      end
    end
  end
end
