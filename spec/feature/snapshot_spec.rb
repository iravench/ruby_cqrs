require_relative('../spec_helper.rb')

describe 'Snapshotable module' do
  let(:command_context) {}
  let(:repository) { RubyCqrs::Domain::AggregateRepository.new\
                     RubyCqrs::Data::InMemoryEventStore.new, command_context }
  let(:aggregate_not_snapshot) { SomeDomain::AggregateRootNoSnapshot.new }
  let(:aggregate) { SomeDomain::AggregateRoot.new }
  # an aggregate has a SNAPSHOT_THRESHOLD of 45
  let(:aggregate_s_45) { SomeDomain::AggregateRoot45Snapshot.new }

  context 'when an aggregate is not snapshotable' do
    it 'specifies an aggregate is not snapshotable' do
      expect(aggregate_not_snapshot.is_a? RubyCqrs::Domain::Snapshotable).to be_falsy
    end

    it "aggregate's #get_changes returns no snapshot field when default amount of events get fired" do
      (1..30).each { |x| aggregate_not_snapshot.test_fire }
      changes = aggregate_not_snapshot.send(:get_changes)
      expect(changes[:snapshot]).to be_nil
    end

    it "saves and loads the correct aggregate back" do
      (1..45).each { |x| aggregate_not_snapshot.test_fire }
      repository.save aggregate_not_snapshot
      loaded_aggregate = repository.find_by aggregate_not_snapshot.aggregate_id
      expect(loaded_aggregate.state).to eq(45)
    end
  end

  context 'when an aggregate is snapshotable' do
    it 'specifies an aggregate is snapshotable' do
      expect(aggregate.is_a? RubyCqrs::Domain::Snapshotable).to be_truthy
      expect(aggregate_s_45.is_a? RubyCqrs::Domain::Snapshotable).to be_truthy
    end

    it "aggregate's #get_changes returns an addtional snapshot field when enough events get fired" do
      (1..30).each { |x| aggregate.test_fire }
      changes = aggregate.send(:get_changes)
      expect(changes[:snapshot]).to_not be_nil

      (1..45).each { |x| aggregate_s_45.test_fire }
      changes = aggregate_s_45.send(:get_changes)
      expect(changes[:snapshot]).to_not be_nil
    end

    it "aggregate's #get_changes returns no snapshot field when not enough events get fired" do
      (1..29).each { |x| aggregate.test_fire }
      changes = aggregate.send(:get_changes)
      expect(changes[:snapshot]).to be_nil

      (1..44).each { |x| aggregate_s_45.test_fire }
      changes = aggregate_s_45.send(:get_changes)
      expect(changes[:snapshot]).to be_nil
    end

    it "saves and loads the correct aggregate back with no snapshots are taken" do
      (1..29).each { |x| aggregate.test_fire }
      repository.save aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(29)

      (1..44).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(44)
    end

    it "saves and loads the correct aggregate back with 1 snapshot's taken" do
      (1..45).each { |x| aggregate.test_fire }
      repository.save aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(45)

      (1..60).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(60)
    end

    it "saves and loads the correct aggregate back incrementally and eventually triggers a snapshot" do
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(15)

      (1..15).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(30)

      (1..30).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(30)

      (1..15).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(45)
    end

    it "saves aggregate incrementally and eventually triggers a snapshot, without reloading aggregate during the process" do
      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      expect(aggregate.state).to eq(15)

      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      expect(aggregate.state).to eq(30)

      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(30)

      (1..30).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      expect(aggregate_s_45.state).to eq(30)

      (1..15).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      expect(aggregate_s_45.state).to eq(45)

      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(45)
    end

    it "saves and loads the correct aggregate back with two snapshot taken" do
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(30)

      (1..30).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(60)

      (1..45).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(45)

      (1..45).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(90)
    end

    it "saves and loads the correct aggregate back incrementally and eventually triggers two snapshot" do
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(30)

      (1..15).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(45)

      (1..15).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate.aggregate_id
      expect(loaded_aggregate.state).to eq(60)

      (1..45).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(45)

      (1..30).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(75)

      (1..15).each { |x| loaded_aggregate.test_fire }
      repository.save loaded_aggregate
      loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
      expect(loaded_aggregate.state).to eq(90)
    end

    it "saves and loads the correct aggregate back incrementally and eventually triggers two snapshot, without reloading aggregate during the process" do
      (1..30).each { |x| aggregate.test_fire }
      repository.save aggregate
      expect(aggregate.state).to eq(30)

      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      expect(aggregate.state).to eq(45)

      (1..15).each { |x| aggregate.test_fire }
      repository.save aggregate
      expect(aggregate.state).to eq(60)

      (1..45).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      expect(aggregate_s_45.state).to eq(45)

      (1..30).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      expect(aggregate_s_45.state).to eq(75)

      (1..15).each { |x| aggregate_s_45.test_fire }
      repository.save aggregate_s_45
      expect(aggregate_s_45.state).to eq(90)
    end
  end
end
