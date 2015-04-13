require_relative('../spec_helper.rb')

# after installing the gem, require the feature
require('ruby_cqrs')
# define your domain object
class Customer
  # mark as a domain object
  include RubyCqrs::Domain::Aggregate
  # makr as snapshotable
  # the default setting is when more 30 events are raised
  # after the last snapshot is taken, a new snapshot is generated
  # change the default by defining SNAPSHOT_THRESHOLD = 20(or other number)
  include RubyCqrs::Domain::Snapshotable

  attr_reader :name, :credit

  # unfortunately, you should not try to define your own initialize method
  # at the time being, it could potentially cause error when the aggregate
  # repository try to load your domain object back.

  # define your domain object's behaviors
  def create_profile name, credit
    # again, this is like your normal initialize method,
    # it should get called only once...
    raise RuntimeError.new('the profile has already been created') unless @name.nil?
    raise AgumentError if name.nil?
    raise AgumentError if credit < 100
    # when business rules are met, raise corresponding event
    raise_event CustomerCreated.new(:name => name, :credit => credit)
  end

  def order_product price
    raise AgumentErrorr if price <= 0
    raise AgumentError.new("#{@name}'s credit #{@credit} is not enough to pay for a product costs #{price}")\
      if price > @credit
    # when business rules are met, raise corresponding event
    raise_event ProductOrdered.new(:cost => price)
  end

private
  # when an event is raised or replayed,
  # these methods will get called automatically,
  # manage the domain object's internal state here
  def on_customer_created customer_created
    @name = customer_created.name
    @credit = customer_created.credit
  end

  def on_product_ordered product_ordered
    @credit -= product_ordered.cost
  end

  # when a domain object is marked as snapshotable,
  # you must implement these two methods to record the object's vital state
  # and apply the snapshot in order to restore your object's data respectively
  def take_a_snapshot
    CustomerSnapshot.new(:name => @name, :credit => @credit)
  end

  def apply_snapshot snapshot_object
    @name = snapshot_object.name
    @credit = snapshot_object.credit
  end
end

# define a snapshot to keep all vital state of your domain object
# the repository will use the latest snapshot it can find
# and events happened after the snapshot has been taken
# to recreate your domain object
class CustomerSnapshot
  include Beefcake::Message
  include RubyCqrs::Domain::Snapshot

  required :name,      :string, 1
  required :credit,    :int32,  2
end

# defined the events your domain object will raise
class CustomerCreated
  include RubyCqrs::Domain::Event
  include Beefcake::Message

  required :name,      :string, 1
  required :credit,    :int32,  2
end

class ProductOrdered
  include RubyCqrs::Domain::Event
  include Beefcake::Message

  required :cost,       :int32,  1
end

# here goes the spec of how you can use the domain object
describe 'Your awesome customer domain objects powered by ruby_cqrs' do
  # a context related to the command, which is specific to your problem domain
  # normally, when a command arrives, one or more domain objects are created or loaded
  # in order to fulfill the command's request
  let(:command_context) {}
  # you should implement your own event_store in order to persist your aggregate state
  # you should read about the InMemoryEventStore implementation
  # and make sure your response with correct data format
  let(:event_store) { RubyCqrs::Data::InMemoryEventStore.new }
  # every time when a command arrives,
  # an aggregate repository gets created with related command context and event_store implementation
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
  end

  it 'operates a new customer instance' do
    lucy.order_product 100

    expect(lucy.name).to eq('Lucy')
    expect(lucy.credit).to eq(900)

    expect(lucy.version).to eq(2)
  end

  it 'saves a new customer instance' do
    lucy.order_product 100
    repository.save lucy

    expect(lucy.name).to eq('Lucy')
    expect(lucy.credit).to eq(900)
    expect(lucy.version).to eq(2)
  end

  it 'finds an old customer instance by id' do
    lucy.order_product 100
    repository.save lucy
    lucy_reload = repository.find_by lucy.aggregate_id

    expect(lucy_reload.name).to eq('Lucy')
    expect(lucy_reload.credit).to eq(900)
    expect(lucy_reload.version).to eq(2)
  end

  it 'operates on an reloaded customer instance' do
    lucy.order_product 100
    repository.save lucy
    lucy_reload = repository.find_by lucy.aggregate_id

    lucy_reload.order_product 200

    expect(lucy_reload.name).to eq('Lucy')
    expect(lucy_reload.credit).to eq(700)
    expect(lucy_reload.version).to eq(3)
  end

  it 'generates a customer snapshot when enough events get fired' do
    (1..30).each { lucy.order_product(10) }
    repository.save lucy

    # well, you just have to trust a snapshot has been generated :)
  end

  it 'finds an old customer instance back from snapshot' do
    (1..30).each { lucy.order_product(10) }
    repository.save lucy
    lucy_reload = repository.find_by lucy.aggregate_id

    # again, it's been loaded from a snapshot ;)

    expect(lucy_reload.name).to eq('Lucy')
    expect(lucy_reload.credit).to eq(700)
    expect(lucy_reload.version).to eq(31)
  end
end
