require 'active_support/inflector'
require 'uuidtools'

module RubyCqrs
  module Domain
    class AggregateBase
      attr_reader :aggregate_id, :version, :source_version

    private
      def initialize
        @aggregate_id = UUIDTools::UUID.timestamp_create.to_s
        @version = 0
        @source_version = 0
        @event_handler_cache = {}
        @pending_events = []
      end

      def raise_event(event)
        apply(event)
        update_dispatch_detail_for(event)
        @pending_events << event
      end

      def load_from sorted_events
        @aggregate_id = sorted_events[0].aggregate_id
        sorted_events.each do |event|
          apply(event)
          @source_version += 1
        end
      end

      def apply(event)
        dispatch_handler_for(event)
        @version += 1
      end

      def dispatch_handler_for(event)
        target = retrieve_handler_for(event.class)
        self.send(target, event)
      end

      def update_dispatch_detail_for(event)
        event.instance_variable_set(:@aggregate_id, @aggregate_id)
        event.instance_variable_set(:@version, @version)
      end

      def retrieve_handler_for(event_type)
        @event_handler_cache[event_type] ||= begin
          stripped_event_type_name = event_type.to_s.demodulize.underscore
          "on_#{stripped_event_type_name}".to_sym
        end
      end

      def get_changes
        return nil unless @pending_events.size > 0
        { :events => @pending_events,
          :aggregate_id => @aggregate_id,
          :aggregate_type => self.class.name,
          :expected_persisted_version => @source_version
        }
      end

      def commit
        @pending_events = []
        @source_version = @version
      end
    end
  end
end
