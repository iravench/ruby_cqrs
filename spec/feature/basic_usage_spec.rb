require_relative('../spec_helper.rb')

class CustomerSnapshot
  include Beefcake::Message
  include RubyCqrs::Data::Encodable

  required :name,      :string, 1
  required :credit,    :int32,  2
end

class CustomerCreated
  include RubyCqrs::Domain::Event
  include Beefcake::Message
  include RubyCqrs::Data::Encodable

  required :name,      :string, 1
  required :credit,    :int32,  2
end

class ProductOrdered
  include RubyCqrs::Domain::Event
  include Beefcake::Message
  include RubyCqrs::Data::Encodable

  required :cost,       :int32,  1
end

class Customer
  # mark customer as a domain object
  include RubyCqrs::Domain::Aggregate
  # makr that customer can be snapshot, the default setting
  # is when 30 events are raised, a snapshot will be generated
  # change by specifying your own constant SNAPSHOT_THRESHOLD
  include RubyCqrs::Domain::Snapshotable

  attr_reader :name, :credit

  # define domain object behaviors
  # when business rules are met, raise corresponding event
  def create_profile name, credit
    raise RuntimeError.new('the profile has already been created') unless @name.nil?
    raise AgumentError if name.nil?
    raise AgumentError if credit < 100
    raise_event CustomerCreated.new(:name => name, :credit => credit)
  end

  def order_product price
    raise AgumentErrorr if price <= 0
    raise AgumentError.new("#{@name}'s credit #{@credit} is not enough to pay for a product costs #{price}")\
      if price > @credit
    raise_event ProductOrdered.new(:cost => price)
  end

private
  # how the raised event affect the domain object's internal state
  def on_customer_created customer_created
    @name = customer_created.name
    @credit = customer_created.credit
  end

  def on_product_ordered product_ordered
    @credit -= product_ordered.cost
  end

  # if a domain object is marked as snapshotable,
  # you must implement bellow two methods to record and revive your object state
  def take_a_snapshot
    CustomerSnapshot.new(:name => @name, :credit => @credit)
  end

  def apply_snapshot snapshot_object
    @name = snapshot_object.name
    @credit = snapshot_object.credit
  end
end

describe 'Your awesome customer domain objects powered by ruby_cqrs' do
  # a context related to the command, which is specific to your problem domain
  let(:command_context) {}
  # every time a command arrives, an aggregate repository gets created with related context
  # and event_store implementation
  let(:event_store) { RubyCqrs::Data::InMemoryEventStore.new }
  let(:repository) { RubyCqrs::Domain::AggregateRepository.new event_store, command_context }

  let(:lucy) do
    instance = Customer.new
    instance.create_profile('Lucy', 1000)
    instance
  end

  it 'creates a new customer instance' do
    expect(lucy.name).to eq('Lucy')
    expect(lucy.credit).to eq(1000)

    expect(lucy.version).to eq(1)
    expect(lucy.instance_variable_get(:@source_version)).to eq(0)
  end

  it 'operates a new customer instance' do
    lucy.order_product 100

    expect(lucy.name).to eq('Lucy')
    expect(lucy.credit).to eq(900)

    expect(lucy.version).to eq(2)
    expect(lucy.instance_variable_get(:@source_version)).to eq(0)
  end

  it 'saves a new customer instance' do
    lucy.order_product 100
    repository.save lucy

    expect(lucy.name).to eq('Lucy')
    expect(lucy.credit).to eq(900)
    expect(lucy.version).to eq(2)
    expect(lucy.instance_variable_get(:@source_version)).to eq(2)
  end

  it 'loads a old customer instance back' do
    lucy.order_product 100
    repository.save lucy
    lucy_reload = repository.find_by lucy.aggregate_id

    expect(lucy_reload.name).to eq('Lucy')
    expect(lucy_reload.credit).to eq(900)
    expect(lucy_reload.version).to eq(2)
    expect(lucy_reload.instance_variable_get(:@source_version)).to eq(2)
  end

  it 'operates on an old customer instance which is loaded back' do
    lucy.order_product 100
    repository.save lucy
    lucy_reload = repository.find_by lucy.aggregate_id

    lucy_reload.order_product 200

    expect(lucy_reload.name).to eq('Lucy')
    expect(lucy_reload.credit).to eq(700)
    expect(lucy_reload.version).to eq(3)
    expect(lucy_reload.instance_variable_get(:@source_version)).to eq(2)
  end

  it 'generates a customer snapshot when enough events get fired' do
    (1..30).each { lucy.order_product(10) }
    repository.save lucy
    snapshot_store = event_store.instance_variable_get(:@snapshot_store)

    expect(snapshot_store.has_key?(lucy.aggregate_id.to_sym)).to be_truthy
    expect(snapshot_store[lucy.aggregate_id.to_sym][:version]).to eq(31)
  end

  it 'loads a customer instance back from snapshot' do
    (1..30).each { lucy.order_product(10) }
    repository.save lucy
    lucy_reload = repository.find_by lucy.aggregate_id

    expect(lucy_reload.name).to eq('Lucy')
    expect(lucy_reload.credit).to eq(700)
    expect(lucy_reload.version).to eq(31)
    expect(lucy_reload.instance_variable_get(:@source_version)).to eq(31)
  end
end
