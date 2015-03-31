module RubyCqrs
  module Domain
    class Event
      attr_reader :aggregate_id, :version
    end
  end
end
