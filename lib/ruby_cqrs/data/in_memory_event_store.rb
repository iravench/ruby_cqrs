module RubyCqrs
  module Data
    class InMemoryEventStore
      include EventStore

      def initialize
        @aggregate_store = {}
        @event_store = {}
        @snapshot_store = {}
      end

      def load_by guid, command_context
        key = guid.to_sym
        state = { :aggregate_id => guid,
                  :aggregate_type => @aggregate_store[key][:type] }

        if @snapshot_store.has_key? key
          extract_state_with_snapshot key, state
        else
          state[:events] = @event_store[key][:events]
        end

        state
      end

      def save changes, command_context
        changes.each do |change|
          key = change[:aggregate_id].to_sym
          verify_state key, change
        end
        changes.each do |change|
          key = change[:aggregate_id].to_sym
          create_aggregate key, change
          update_aggregate key, change
        end
        nil
      end

    private
      def create_aggregate key, change
        unless @aggregate_store.has_key? key
          @aggregate_store[key] = { :type => change[:aggregate_type], :version => 0 }
          @event_store[key] = { :events => [] }
        end
        @snapshot_store[key] = {} unless change[:snapshot].nil?
      end

      def update_aggregate key, change
        @aggregate_store[key][:version] = change[:expecting_version]
        change[:events].each { |event| @event_store[key][:events] << event }
        @snapshot_store[key] = change[:snapshot] unless change[:snapshot].nil?
      end

      def extract_state_with_snapshot key, state
        snapshot_version = @snapshot_store[key][:version]
        state[:events] = @event_store[key][:events]\
          .select { |event_record| event_record[:version] > snapshot_version }
        state[:snapshot] = @snapshot_store[key]
      end

      def verify_state key, change
        raise AggregateConcurrencyError.new("on aggregate #{key}")\
          if @aggregate_store.has_key? key\
            and @aggregate_store[key][:version] != change[:expecting_source_version]
      end
    end
  end
end
