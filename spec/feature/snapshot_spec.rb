require_relative('../spec_helper.rb')

describe 'snapshot feature' do
  let(:command_context) {}
  let(:event_store) { RubyCqrs::Data::InMemoryEventStore.new }
  let(:repository) {
    RubyCqrs::Domain::AggregateRepository.new\
      event_store, command_context }
  let(:aggregate) { SomeDomain::AggregateRoot.new }

  it 'specifies an aggregate is snapshotable' do
    expect(aggregate.is_a? RubyCqrs::Domain::Snapshotable).to be_truthy
  end

  it "aggregate's #get_changes returns an addtional snapshot field when enough events get fired" do
    (1..30).each { |x| aggregate.test_fire }
    changes = aggregate.send(:get_changes)
    expect(changes[:snapshot]).to_not be_nil
  end

  it 'saves and is able to load the correct aggregate back' do
    (1..30).each { |x| aggregate.test_fire }
    repository.save aggregate
    loaded_aggregate = repository.find_by aggregate.aggregate_id

    expect(loaded_aggregate.state).to eq(30)
  end

end
