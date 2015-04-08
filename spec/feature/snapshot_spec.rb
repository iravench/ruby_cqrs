require_relative('../spec_helper.rb')

describe 'snapshot feature' do
  let(:command_context) {}
  let(:event_store) { RubyCqrs::Data::InMemoryEventStore.new }
  let(:repository) {
    RubyCqrs::Domain::AggregateRepository.new\
      event_store, command_context }
  let(:aggregate) { SomeDomain::AggregateRoot.new }
  let(:aggregate_s_45) { SomeDomain::AggregateRoot45Snapshot.new }

  it 'specifies an aggregate is snapshotable' do
    expect(aggregate.is_a? RubyCqrs::Domain::Snapshotable).to be_truthy
  end

  it "aggregate's #get_changes returns an addtional snapshot field when enough events get fired" do
    (1..30).each { |x| aggregate.test_fire }
    changes = aggregate.send(:get_changes)
    expect(changes[:snapshot]).to_not be_nil
  end

  it 'saves and is able to load the correct aggregate_s_45 back(30 events)' do
    (1..30).each { |x| aggregate_s_45.test_fire }
    repository.save aggregate_s_45
    loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
    expect(loaded_aggregate.state).to eq(30)
  end

  it 'saves and is able to load the correct aggregate_s_45 back(60 events)' do
    (1..60).each { |x| aggregate_s_45.test_fire }
    repository.save aggregate_s_45
    loaded_aggregate = repository.find_by aggregate_s_45.aggregate_id
    expect(loaded_aggregate.state).to eq(60)
  end

  it 'saves and is able to load the correct aggregate back(30 events)' do
    (1..30).each { |x| aggregate.test_fire }
    repository.save aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(30)
  end

  it 'saves and is able to load the correct aggregate back(60 events)' do
    (1..60).each { |x| aggregate.test_fire }
    repository.save aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(60)
  end

  it 'saves and is able to load the correct aggregate back(45 events)' do
    (1..30).each { |x| aggregate.test_fire }
    repository.save aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(30)

    (1..15).each { |x| loaded_aggregate.test_fire }
    repository.save loaded_aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(45)
  end

  it 'saves and is able to load the correct aggregate back(45 events), without reloading aggregate' do
    (1..30).each { |x| aggregate.test_fire }
    repository.save aggregate
    expect(aggregate.state).to eq(30)

    (1..15).each { |x| aggregate.test_fire }
    repository.save aggregate
    expect(aggregate.state).to eq(45)

    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(45)
  end

  it 'saves and is able to load the correct aggregate back(60 events)' do
    (1..30).each { |x| aggregate.test_fire }
    repository.save aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(30)

    (1..30).each { |x| loaded_aggregate.test_fire }
    repository.save loaded_aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(60)
  end

  it 'saves and is able to load the correct aggregate back(75 events)' do
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

    (1..15).each { |x| loaded_aggregate.test_fire }
    repository.save loaded_aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id
    expect(loaded_aggregate.state).to eq(75)
  end
end
