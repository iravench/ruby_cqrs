require_relative('../spec_helper')

describe RubyCqrs::Data::InMemoryEventStore do
  let(:command_context) {}
  let(:event_store) { RubyCqrs::Data::InMemoryEventStore.new }
  let(:repository) { RubyCqrs::Domain::AggregateRepository.new\
                     event_store, command_context }
  let(:aggregate_type) { SomeDomain::AggregateRoot }
  let(:aggregate_type_str) { SomeDomain::AggregateRoot.to_s }
  # an aggregate has a SNAPSHOT_THRESHOLD of 45
  let(:aggregate_s_45_type) { SomeDomain::AggregateRoot45Snapshot }
  let(:aggregate_s_45_type_str) { SomeDomain::AggregateRoot45Snapshot.to_s }

  describe '#load & #save' do
    it 'saves a new aggregate then is able to load the correct data back' do
      new_aggregate = aggregate_type.new
      new_aggregate.test_fire
      new_aggregate.test_fire_ag
      repository.save new_aggregate

      state = event_store.load_by new_aggregate.aggregate_id, command_context
      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(2)
      expect(state[:events][0][:version]).to eq(1)
      expect(state[:events][0][:aggregate_id]).to eq(new_aggregate.aggregate_id)
      expect(state[:events][1][:version]).to eq(2)
      expect(state[:events][1][:aggregate_id]).to eq(new_aggregate.aggregate_id)
    end

    it 'saves an existing aggregate then is able to load the correct data back' do
      new_aggregate = aggregate_type.new
      new_aggregate.test_fire
      new_aggregate.test_fire_ag
      repository.save new_aggregate
      old_aggregate = repository.find_by new_aggregate.aggregate_id
      old_aggregate.test_fire
      old_aggregate.test_fire_ag
      repository.save old_aggregate
      state = event_store.load_by old_aggregate.aggregate_id, command_context

      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(4)
      expect(state[:events][0][:version]).to eq(1)
      expect(state[:events][0][:aggregate_id]).to eq(old_aggregate.aggregate_id)
      expect(state[:events][1][:version]).to eq(2)
      expect(state[:events][1][:aggregate_id]).to eq(old_aggregate.aggregate_id)
      expect(state[:events][2][:version]).to eq(3)
      expect(state[:events][2][:aggregate_id]).to eq(old_aggregate.aggregate_id)
      expect(state[:events][3][:version]).to eq(4)
      expect(state[:events][3][:aggregate_id]).to eq(old_aggregate.aggregate_id)
    end

    it "receives correct input on #save with 1 snapshot taken when enough events get fired" do
      aggregate = aggregate_type.new
      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      aggregate = aggregate_s_45_type.new
      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate
    end

    it "receives correct input on #save with 1 snapshot taken when enough events get fired, also test result" do
      aggregate = aggregate_type.new
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(30)

      aggregate = aggregate_s_45_type.new
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_s_45_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot]).to_not be_nil
    end

    it "receives correct input on #save with no snapshot taken when not enough events get fired" do
      aggregate = aggregate_type.new
      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..29).each { |x| aggregate.test_fire }
      repository.save aggregate

      aggregate = aggregate_s_45_type.new
      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..44).each { |x| aggregate.test_fire }
      repository.save aggregate
    end

    it "receives correct input on #save with no snapshot taken when not enough events get fired, also test result" do
      aggregate = aggregate_type.new
      (1..29).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(29)
      expect(state[:snapshot]).to be_nil

      aggregate = aggregate_s_45_type.new
      (1..44).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_s_45_type_str)
      expect(state[:events].size).to eq(44)
      expect(state[:snapshot]).to be_nil
    end

    it "receives correct input on #save incrementally and eventually triggers a snapshot" do
      aggregate = aggregate_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      aggregate = aggregate_s_45_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
    end

    it "receives correct input on #save incrementally and eventually triggers a snapshot, also test result" do
      aggregate = aggregate_type.new
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(30)

      aggregate = aggregate_s_45_type.new
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_s_45_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(45)
    end

    it "receives correct input on #save with 1 snapshot taken when more than enough events get fired" do
      aggregate = aggregate_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate

      aggregate = aggregate_s_45_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..60).each { |x| aggregate.test_fire }
      repository.save aggregate
    end

    it "receives correct input on #save with 1 snapshot taken when more than enough events get fired, also test result" do
      aggregate = aggregate_type.new
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(45)

      aggregate = aggregate_s_45_type.new
      (1..60).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_s_45_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(60)
    end

    it "receives correct input on #save with 1 snapshot taken when enough events get fired, twice" do
      aggregate = aggregate_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      aggregate = aggregate_s_45_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate
    end

    it "receives correct input on #save with 1 snapshot taken when enough events get fired, twice, also test result" do
      aggregate = aggregate_type.new
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(60)

      aggregate = aggregate_s_45_type.new
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_s_45_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(90)
    end

    it "receives correct input on #save incrementally and eventually triggers two snapshots" do
      aggregate = aggregate_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      aggregate = aggregate_s_45_type.new

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to be_nil }
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate

      expect(event_store).to receive(:save)\
        { |changes, context| expect(changes[0][:snapshot]).to_not be_nil }
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
    end

    it "receives correct input on #save incrementally and eventually triggers two snapshots, also test result" do
      aggregate = aggregate_type.new
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_type_str)
      expect(state[:events].size).to eq(15)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(60)

      aggregate = aggregate_s_45_type.new
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate

      state = event_store.load_by aggregate.aggregate_id, command_context
      expect(state[:aggregate_id]).to eq(aggregate.aggregate_id)
      expect(state[:aggregate_type]).to eq(aggregate_s_45_type_str)
      expect(state[:events].size).to eq(0)
      expect(state[:snapshot][:data]).to_not be_nil
      expect(state[:snapshot][:version]).to be(105)
    end

    it 'raises concurrency error when two instances of the same aggregate try to compete with each other' do
      # obtain two instances of the same aggregate
      new_aggregate = aggregate_type.new
      new_aggregate.test_fire
      new_aggregate.test_fire_ag
      repository.save new_aggregate
      instance_1 = new_aggregate
      instance_2 = repository.find_by new_aggregate.aggregate_id

      # now both instances try to compete with each other
      instance_1.test_fire
      instance_2.test_fire

      # only one instance of the two could be saved successfully
      repository.save instance_1
      expect(instance_1.version).to eq(instance_1.instance_variable_get(:@source_version))
      expect{ repository.save instance_2 }.to raise_error(RubyCqrs::AggregateConcurrencyError)
      expect(instance_2.version).to_not eq(instance_2.instance_variable_get(:@source_version))
    end

    it 'makes sure no state could be persisted if any error occured during the save process' do
      # obtain two instances of the same aggregate
      instance_1 = aggregate_type.new
      instance_1.test_fire
      instance_1.test_fire_ag
      repository.save instance_1
      instance_2 = repository.find_by instance_1.aggregate_id

      # now both instances try to compete with each other
      instance_1.test_fire
      instance_2.test_fire

      # instance 1 wins the save
      repository.save instance_1

      # instance 3 has done its work and ready to be persisted
      instance_3 = aggregate_type.new
      instance_3.test_fire

      # when trying to save instance 2 and 3 together, instance 2 would trigger an error
      # so both instance 2 and 3 could not be persisted
      expect{ repository.save [ instance_3, instance_2 ] }.to\
        raise_error(RubyCqrs::AggregateConcurrencyError)
      expect(instance_1.version).to eq(instance_1.instance_variable_get(:@source_version))
      expect(instance_2.version).to_not eq(instance_2.instance_variable_get(:@source_version))
      expect(instance_3.version).to_not eq(instance_3.instance_variable_get(:@source_version))
    end
  end
end
