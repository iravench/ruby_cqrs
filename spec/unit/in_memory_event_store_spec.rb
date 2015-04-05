require_relative('../spec_helper')

describe RubyCqrs::Data::InMemoryEventStore do
  let(:command_context) {}
  let(:event_store) { RubyCqrs::Data::InMemoryEventStore.new }
  let(:repository) {
    RubyCqrs::Domain::AggregateRepository.new\
      event_store, command_context }
  let(:aggregate_type) { SomeDomain::AggregateRoot }
  let(:aggregate_type_str) { SomeDomain::AggregateRoot.to_s }
  let(:new_aggregate) {
    aggregate_root = aggregate_type.new
    aggregate_root.test_fire
    aggregate_root.test_fire_ag
    aggregate_root
  }
  let(:old_aggregate) {
    aggregate_root = new_aggregate
    repository.save aggregate_root
    aggregate_root.test_fire
    aggregate_root.test_fire_ag
    aggregate_root
  }

  describe '#load & #save' do
    it 'saves a new aggregate then is able to load the corret data back' do
      repository.save new_aggregate
      loaded_type_str, loaded_events = event_store.load_by\
        new_aggregate.aggregate_id, command_context

      expect(loaded_type_str).to eq(aggregate_type_str)
      expect(loaded_events.size).to eq(2)
      expect(loaded_events[0].version).to eq(1)
      expect(loaded_events[0].aggregate_id).to eq(new_aggregate.aggregate_id)
      expect(loaded_events[1].version).to eq(2)
      expect(loaded_events[1].aggregate_id).to eq(new_aggregate.aggregate_id)
    end

    it 'saves an existing aggregate then is able to load the corret data back' do
      repository.save old_aggregate
      loaded_type_str, loaded_events = event_store.load_by\
        old_aggregate.aggregate_id, command_context

      expect(loaded_type_str).to eq(aggregate_type_str)
      expect(loaded_events.size).to eq(4)
      expect(loaded_events[0].version).to eq(1)
      expect(loaded_events[0].aggregate_id).to eq(old_aggregate.aggregate_id)
      expect(loaded_events[1].version).to eq(2)
      expect(loaded_events[1].aggregate_id).to eq(old_aggregate.aggregate_id)
      expect(loaded_events[2].version).to eq(3)
      expect(loaded_events[2].aggregate_id).to eq(old_aggregate.aggregate_id)
      expect(loaded_events[3].version).to eq(4)
      expect(loaded_events[3].aggregate_id).to eq(old_aggregate.aggregate_id)
    end

    it 'raise concurrency error when attempting to save more than one aggregate instances start from the same state' do
      # obtain two instances of the save state
      repository.save new_aggregate
      instance_1 = new_aggregate
      instance_2 = repository.find_by instance_1.aggregate_id

      instance_1.test_fire
      instance_2.test_fire

      repository.save instance_1
      expect(instance_1.version).to eq(instance_1.source_version)
      expect{ repository.save instance_2 }.to raise_error(RubyCqrs::AggregateConcurrencyError)
      expect(instance_2.version).to_not eq(instance_2.source_version)
    end
  end
end
