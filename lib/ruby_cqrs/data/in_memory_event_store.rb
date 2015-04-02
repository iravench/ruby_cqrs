require 'beefcake'

module RubyCqrs
  module Data
    class InMemoryEventStore < EventStore
      def initialize
        @aggregate_store = {}
        @event_store = {}
      end

      def load_by guid, command_context
        key = guid.to_sym
        [ @aggregate_store[key][:type], @event_store[key][:events].map { |event| try_decode event } ]
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
          @event_store[key][:events] << { :aggregate_id => event.aggregate_id,\
                                          :event_type => event.class.name,
                                          :version => event.version,
                                          :data => try_encode(event) }
        end
      end

      def try_encode event
        return event.encode.to_s if event.class.include? Beefcake::Message
        event
      end

      def try_decode event
        return event[:data] if event[:data].is_a? RubyCqrs::Domain::Event
        decoded_event = event[:event_type].constantize.decode event[:data]
        decoded_event.instance_variable_set(:@aggregate_id, event[:aggregate_id])
        decoded_event.instance_variable_set(:@version, event[:version])
        decoded_event
      end
    end
  end
end
