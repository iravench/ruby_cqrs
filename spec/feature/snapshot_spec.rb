require_relative('../spec_helper.rb')

describe 'snapshot feature' do
  let(:aggregate) { SomeDomain::AggregateRoot.new }

  it 'specifies an aggregate is snapshotable' do
    expect(aggregate.is_a? RubyCqrs::Domain::Snapshotable).to be_truthy
  end

  it "aggregate's #get_changes returns an addtional snapshot field when enough events get fired" do
    (1..30).each { |x| aggregate.test_fire }
    changes = aggregate.send(:get_changes)
    expect(changes[:snapshot]).to_not be_nil
  end

end
