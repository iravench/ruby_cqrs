module RubyCqrs
  module Data
    class InMemoryEventStore
      include EventStore

      def initialize
        @aggregate_store = {}
        @event_store = {}
        @snapshot_store = {}
      end

      # the returned format is as bellow
      # { :aggregate_id => some_aggregtate_id(uuid),
      #   :aggregate_type => the full qualified name of the aggregate type(string),
      #   :events => [ {:aggregate_id => the aggregate_id of the event belongs to(uuid),
      #                 :event_type => the full qualified name of the event type(string),
      #                 :version => the version number of the event(integer),
      #                 :data => protobuf encoded content of the event object(string)}, ..., {} ],
      #   :snapshot => { :state_type => the full qualified name of the snapshot type(string),
      #                  :version => the version number of the aggregate when snapshot(integer),
      #                  :data => protobuf encoded content of the snapshot object(string)} }
      # the snapshot object could be null; and the events array should return events which has a version
      # number greater than the version number of the returning snapshot, if any.
      def load_by guid, command_context
        key = guid.to_sym
        state = { :aggregate_id => guid,
                  :aggregate_type => @aggregate_store[key][:type] }

        if @snapshot_store.has_key? key
          extract_snapshot_into key, state
        else
          state[:events] = @event_store[key][:events]
        end

        state
      end

      # the changes are defined as an array of aggregate change,
      # each change's format is identical to what above load_by returns
      def save changes, command_context
        changes.each do |change|
          key = change[:aggregate_id].to_sym
          verify_state key, change
        end
        changes.each do |change|
          key = change[:aggregate_id].to_sym
          create_state key, change
          update_state key, change
        end
        nil
      end

    private
      def create_state key, change
        unless @aggregate_store.has_key? key
          @aggregate_store[key] = { :type => change[:aggregate_type], :version => 0 }
          @event_store[key] = { :events => [] }
        end
        unless @snapshot_store.has_key? key or change[:snapshot].nil?
          @snapshot_store[key] = {}
        end
      end

      def update_state key, change
        @aggregate_store[key][:version] = change[:expecting_version]
        change[:events].each { |event| @event_store[key][:events] << event }
        @snapshot_store[key] = change[:snapshot] unless change[:snapshot].nil?
      end

      def extract_snapshot_into key, state
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
