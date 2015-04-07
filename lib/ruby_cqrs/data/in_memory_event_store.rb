module RubyCqrs
  module Data
    class InMemoryEventStore < EventStore
      include Decodable

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
          snapshot_version = @snapshot_store[key][:version]
          state[:events] = @event_store[key][:events]\
            .select { |event_record| event_record[:version] > snapshot_version }\
            .map { |event_record| decode_event_from event_record }
          snapshot_state = decode_snapshot_state_from @snapshot_store[key]
          state[:snapshot] = { :state => snapshot_state,
                               :version => snapshot_version }
        else
          state[:events] = @event_store[key][:events]\
            .map { |event_record| decode_event_from event_record }
        end

        state
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
        @aggregate_store[key] = { :type => change[:aggregate_type], :version => 0 }
        @event_store[key] = { :events => [] }
        @snapshot_store[key] = {} unless change[:snapshot].nil?
      end

      def update_aggregate key, change
        @aggregate_store[key][:version] = change[:expecting_version]

        change[:events].each do |event|
          data = encode_data_from event
          @event_store[key][:events] << { :aggregate_id => event.aggregate_id,
                                          :event_type => event.class.name,
                                          :version => event.version,
                                          :data => data }
        end

        unless change[:snapshot].nil?
          data = encode_data_from change[:snapshot][:state]
          @snapshot_store[key][:state] = data
          @snapshot_store[key][:state_type] = change[:snapshot][:state_type]
          @snapshot_store[key][:version] = change[:snapshot][:version]
        end
      end

      def verify_state key, change
        raise AggregateConcurrencyError.new("on aggregate #{key}")\
          unless @aggregate_store[key][:version] == change[:expecting_source_version]
      end

      def decode_event_from event_record
        decoded_event = try_decode event_record[:event_type], event_record[:data]
        decoded_event.instance_variable_set(:@aggregate_id, event_record[:aggregate_id])
        decoded_event.instance_variable_set(:@version, event_record[:version])
        decoded_event
      end

      def decode_snapshot_state_from snapshot_record
        try_decode snapshot_record[:state_type], snapshot_record[:state]
      end

      def encode_data_from obj
        data = obj
        data = data.try_encode if data.is_a? Encodable
        data
      end
    end
  end
end
