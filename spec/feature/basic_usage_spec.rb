require_relative('../spec_helper.rb')

# after installing the gem, require its features
require('ruby_cqrs')
# define your domain object
class Customer
  # mark your domain object as an aggregate
  include RubyCqrs::Domain::Aggregate
  # optionally, also makr as snapshotable in order to avoid heavy events reading pressure
  # if your aggregate won't be generating much events, you can just ignore this
  # the default setting is thant when over 30 events get raised after the last snapshot taken,
  # a new snapshot will be generated upon calling aggregate_repository.save
  # change this default value by defining SNAPSHOT_THRESHOLD = 20(or other number)
  include RubyCqrs::Domain::Snapshotable

  attr_reader :name, :credit

  # unfortunately, you should not try to define your own initialize method with parameters
  # at the time being, it could potentially cause error with aggregate_repository
  # when it tries to instantiate an aggregate back to live.
  # Still looking for better way to do this.

  # define domain behaviors
  def create_profile name, credit
    # again, this one method kinda serve as your normal initialize method here,
    # which means it should be called once only
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
  # when an event gets raised or replayed, these on_ methods will be called automatically,
  # with the events's detail information, you can manage the aggregate's internal state
  def on_customer_created customer_created
    @name = customer_created.name
    @credit = customer_created.credit
  end

  def on_product_ordered product_ordered
    @credit -= product_ordered.cost
  end

  # when an aggregate is marked as snapshotable,
  # following two methods must be implemented in order to record and restore
  # the aggregate's vital state respectively,
  def take_a_snapshot
    CustomerSnapshot.new(:name => @name, :credit => @credit)
  end

  def apply_snapshot snapshot_object
    @name = snapshot_object.name
    @credit = snapshot_object.credit
  end
end

# define a snapshot to keep all vital state
# the repository will look for the latest snapshot it can find, plus
# all events happened right after when that particular snapshot gets taken
# in order to revive your aggregate instance
class CustomerSnapshot
  include Beefcake::Message
  include RubyCqrs::Domain::Snapshot

  required :name,      :string, 1
  required :credit,    :int32,  2
end

# defined the events your aggregate will raise
# your domain's event collection can be defined in a way easy to share among teams
# which enables smooth integration through event logs
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

# here goes the spec of how you can use previously defined aggregate objects
describe 'Your awesome customer domain objects powered by ruby_cqrs' do
  # a context related to a command, which is specific to your problem domain
  # normally, when the command arrives, one or more domain objects are activated
  # in order to fulfill the command's request
  #
  # a command context then encapsulates any information which could be of importance
  # but not part of your current domain, you can later choose to persist all or
  # part of the context to support further processing or integration.
  let(:command_context) {}
  # you should implement your own event_store in order to persist aggregate state
  # you can read about the InMemoryEventStore implementation
  # to understand the data format pass in and out
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

    # well, you'll just have to trust me a snapshot has been generated :)
  end

  it 'finds an old customer instance back from snapshot' do
    (1..30).each { lucy.order_product(10) }
    repository.save lucy
    lucy_reload = repository.find_by lucy.aggregate_id

    # again, a snapshot has been applied to gain you a bit performance boost ;)

    expect(lucy_reload.name).to eq('Lucy')
    expect(lucy_reload.credit).to eq(700)
    expect(lucy_reload.version).to eq(31)
  end
end
