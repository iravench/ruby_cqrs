require 'beefcake'

module SomeDomain
  class AggregateRoot
    include RubyCqrs::Domain::Aggregate
    include RubyCqrs::Domain::Snapshotable

    attr_reader :state

    def initialize
      @state = 0
      super
    end

    def fire_weird_stuff
      raise_event Object.new
    end

    def test_fire
      raise_event THIRD_EVENT_INSTANCE
    end

    def test_fire_ag
      raise_event FORTH_EVENT_INSTANCE
    end

  private
    def on_first_event event; @state += 1; end
    def on_second_event event; @state += 1; end
    def on_third_event event; @state += 1; end
    def on_forth_event event; @state += 1; end

    def take_a_snapshot
      Snapshot.new(:state => @state)
    end

    def apply_snapshot snapshot_object
      @state = snapshot_object.state
    end
  end

  class Snapshot
    include Beefcake::Message

    required :state,      :int32, 1
  end

  AGGREGATE_ID = 'cbb688cc-d49a-11e4-9f39-3c15c2d13d4e'

  class FirstEvent
    include RubyCqrs::Domain::Event
    def initialize
      @aggregate_id = AGGREGATE_ID
      @version = 1
    end
  end

  class SecondEvent
    include RubyCqrs::Domain::Event
    def initialize
      @aggregate_id = AGGREGATE_ID
      @version = 2
    end
  end

  class ThirdEvent
    include RubyCqrs::Domain::Event
    include Beefcake::Message

    required :id,         :int32,   1
    required :name,       :string,  2
    required :phone,      :string,  3

    optional :note,       :string,  4
  end

  class ForthEvent
    include RubyCqrs::Domain::Event
    include Beefcake::Message

    required :order_id,   :int32,   1
    required :price,      :int32,   2
    required :customer_id,:int32,   3

    optional :note,       :string,  4
  end

  THIRD_EVENT_INSTANCE = ThirdEvent.new(:id => 1, :name => 'some dude',\
                                        :phone => '13322244444', :note => 'good luck')

  FORTH_EVENT_INSTANCE = ForthEvent.new(:order_id => 100, :price => 2000,\
                                        :customer_id => 1, :note => 'sold!')

  SORTED_EVENTS = [FirstEvent.new, SecondEvent.new]
  UNSORTED_EVENTS = [SecondEvent.new, FirstEvent.new]
end
