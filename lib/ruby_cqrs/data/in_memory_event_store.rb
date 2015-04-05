module RubyCqrs
  module Data
    class InMemoryEventStore < EventStore
      include ProtobufableEvent

      def initialize
        @aggregate_store = {}
        @event_store = {}
      end

      def load_by guid, command_context
        key = guid.to_sym
        [ @aggregate_store[key][:type],
          @event_store[key][:events].map { |event_record| try_decode event_record } ]
      end

      # notice there could be partial save here when verify_state raise an error
      def save changes, command_context
        changes.each do |change|
          key = change[:aggregate_id].to_sym
          create_aggregate key, change unless @aggregate_store.has_key? key
          verify_state key, change
          update_aggregate key, change
        end
        nil
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
          @event_store[key][:events] << { :aggregate_id => event.aggregate_id,
                                          :event_type => event.class.name,
                                          :version => event.version,
                                          :data => try_encode(event) }
        end
      end

      def verify_state key, change
        raise AggregateConcurrencyError.new("on aggregate #{key}")\
          unless @aggregate_store[key][:version] == change[:expecting_source_version]
      end
    end
  end
end
