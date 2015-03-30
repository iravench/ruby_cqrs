module SomeDomain
  class AggregateRoot < RubyCqrs::Domain::AggregateBase
    def test_fire; raise_event ThirdEvent.new; end
    def test_fire_ag; raise_event ForthEvent.new; end
  private
    def on_first_event event; end
    def on_second_event event; end
    def on_third_event event; end
    def on_forth_event event; end
  end

  AGGREGATE_ID = 'cbb688cc-d49a-11e4-9f39-3c15c2d13d4e'

  class FirstEvent < RubyCqrs::Domain::Event
    def initialize
      @aggregate_id = AGGREGATE_ID
      @version = 1
    end
  end

  class SecondEvent < RubyCqrs::Domain::Event
    def initialize
      @aggregate_id = AGGREGATE_ID
      @version = 2
    end
  end

  class ThirdEvent < RubyCqrs::Domain::Event; end
  class ForthEvent < RubyCqrs::Domain::Event; end

  SORTED_EVENTS = [FirstEvent.new, SecondEvent.new]
end
