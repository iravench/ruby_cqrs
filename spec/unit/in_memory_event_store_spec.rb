require_relative('../spec_helper')

# should event store's super class takes care of event serialization
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
    repository.save aggregate_root
    aggregate_root
  }
  let(:old_aggregate) {
    aggregate_root = new_aggregate
    aggregate_root.test_fire
    aggregate_root.test_fire_ag
    repository.save aggregate_root
    aggregate_root
  }

  describe '#load & #save' do
    it 'saves a new aggregate then is able to load the corret data back' do
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
  end
end
