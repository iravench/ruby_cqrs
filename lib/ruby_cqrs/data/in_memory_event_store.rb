module RubyCqrs
  module Data
    class InMemoryEventStore < EventStore
      def initialize
        @aggregate_store = {}
        @event_store = {}
      end

      def load_by guid, command_context
        key = guid.to_sym
        [ @aggregate_store[key][:type], @event_store[key][:events] ]
      end

      def save changes, command_context
        changes.each do |change|
          key = change[:aggregate_id].to_sym
          create_aggregate key, change unless @aggregate_store.has_key? key
          update_aggregate key, change
        end
      end

    private
      def create_aggregate key, change
        @aggregate_store[key] = {
          :type => change[:aggregate_type],
          :version => 0 }
        @event_store[key] = { :events => [] }
      end

      def update_aggregate key, change
        @aggregate_store[key][:version] = change[:expecting_version]
        change[:events].each do |event|
          @event_store[key][:events] << event
        end
      end
    end
  end
end
