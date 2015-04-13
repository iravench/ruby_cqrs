require 'active_support/inflector'

module RubyCqrs
  module Domain
    module Aggregate
      attr_reader :aggregate_id, :version

      def initialize
        @aggregate_id = Guid.create
        @version = 0
        @source_version = 0
        @event_handler_cache = {}
        @pending_events = []
        super
      end

      def is_version_conflicted? client_side_version
        client_side_version != @source_version
      end

    private

      def load_from state
        sorted_events = state[:events].sort { |x, y| x.version <=> y.version }
        @aggregate_id = state[:aggregate_id]
        try_load_snapshot_from state
        sorted_events.each do |event|
          apply(event)
          @source_version += 1
        end
      end

      def try_load_snapshot_from state
        if state.has_key? :snapshot and self.is_a? Snapshotable
          self.send :apply_snapshot, state[:snapshot][:state]
          @version = state[:snapshot][:version]
          @source_version = state[:snapshot][:version]
          self.send(:reset_countdown, state[:events].size)
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
        try_extract_snapshot_into changes
        changes
      end

      def try_extract_snapshot_into changes
        snapshot_state = self.send :take_a_snapshot\
          if self.is_a? Snapshotable and self.send(:should_take_a_snapshot?)
        unless snapshot_state.nil?
          raise NotADomainSnapshotError unless snapshot_state.is_a? Snapshot
          changes[:snapshot] = { :state => snapshot_state,
                                 :state_type => snapshot_state.class.name,
                                 :version => @version }
          self.send :set_snapshot_taken
        end
      end

      def commit
        @pending_events = []
        @source_version = @version
        if self.is_a? Snapshotable and self.send :should_reset_snapshot_countdown?
          self.send(:reset_countdown, 0)
        end
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
