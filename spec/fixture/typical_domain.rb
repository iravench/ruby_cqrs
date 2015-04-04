require 'beefcake'

module SomeDomain
  class AggregateRoot
    include RubyCqrs::Domain::Aggregate

    def fire_weird_stuff
      raise_event Object.new
    end

    def test_fire
      raise_event ThirdEvent.new(:id => 1, :name => 'some dude',\
                                 :phone => '13322244444', :note => 'good luck')
    end

    def test_fire_ag
      raise_event ForthEvent.new(:order_id => 100, :price => 2000,\
                                 :customer_id => 1, :note => 'sold!')
    end
  private
    def on_first_event event; end
    def on_second_event event; end
    def on_third_event event; end
    def on_forth_event event; end
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

  SORTED_EVENTS = [FirstEvent.new, SecondEvent.new]
  UNSORTED_EVENTS = [SecondEvent.new, FirstEvent.new]
end
