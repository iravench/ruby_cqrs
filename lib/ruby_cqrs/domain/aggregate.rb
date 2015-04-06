require 'active_support/inflector'

module RubyCqrs
  module Domain
    module Aggregate
      attr_reader :aggregate_id, :version, :source_version

    private
      def initialize
        @aggregate_id = Guid.create
        @version = 0
        @source_version = 0
        @event_handler_cache = {}
        @pending_events = []
        super
      end

      def load_from events
        sorted_events = events.sort { |x, y| x.version <=> y.version }
        @aggregate_id = sorted_events[0].aggregate_id
        sorted_events.each do |event|
          apply(event)
          @source_version += 1
        end
      end

      def get_changes
        return nil unless @pending_events.size > 0
        changes = {
          :events => @pending_events,
          :aggregate_id => @aggregate_id,
          :aggregate_type => self.class.name,
          :expecting_source_version => @source_version,
          :expecting_version => @pending_events.max\
          { |a, b| a.version <=> b.version }.version
        }
        changes[:snapshot] = self.send :take_a_snapshot if self.is_a? Snapshotable\
          and self.send(:should_take_a_snapshot?) and self.respond_to? :take_a_snapshot, true
        changes
      end

      def commit
        @pending_events = []
        @source_version = @version
      end

      def raise_event(event)
        raise NotADomainEventError unless event.is_a? Event
        apply(event)
        update_dispatch_detail_for(event)
        @pending_events << event
      end

      def update_dispatch_detail_for(event)
        event.instance_variable_set(:@aggregate_id, @aggregate_id)
        event.instance_variable_set(:@version, @version)
      end

      def apply(event)
        dispatch_handler_for(event)
        self.send(:snapshot_countdown) if self.is_a? Snapshotable
        @version += 1
      end

      def dispatch_handler_for(event)
        target = retrieve_handler_for(event.class)
        self.send(target, event)
      end

      def retrieve_handler_for(event_type)
        @event_handler_cache[event_type] ||= begin
          stripped_event_type_name = event_type.to_s.demodulize.underscore
          "on_#{stripped_event_type_name}".to_sym
        end
      end
    end
  end
end
