require 'active_support/inflector'
require 'contracts'
require_relative '../contracts'

module RubyCqrs
  module Domain
    module Aggregate
      include Contracts
      include Contracts::Modules

      attr_reader :aggregate_id, :version

      Contract None => Any
      def initialize
        @aggregate_id = Guid.create
        @version = 0
        @source_version = 0
        @event_handler_cache = {}
        @pending_events = []
        super
      end

      Contract Pos => Bool
      def is_version_conflicted? client_side_version
        client_side_version != @source_version
      end

    private
      Contract Or[Validation::AggregateState, Validation::AggregateStateWithSnapshot] => nil
      def load_from state
        sorted_events = state[:events].sort { |x, y| x.version <=> y.version }
        @aggregate_id = state[:aggregate_id]
        try_apply_snapshot_in state
        sorted_events.each do |event|
          apply(event)
          @source_version += 1
        end
        nil
      end

      Contract Or[Validation::AggregateState, Validation::AggregateStateWithSnapshot] => nil
      def try_apply_snapshot_in state
        if state.has_key? :snapshot and self.is_a? Snapshotable
          self.send :apply_snapshot, state[:snapshot][:state]
          @version = state[:snapshot][:version]
          @source_version = state[:snapshot][:version]
          self.send(:reset_countdown, state[:events].size)
        end
        nil
      end

      Contract None => Or[nil, Validation::AggregateChanges, Validation::AggregateChangesWithSnapshot]
      def get_changes
        return nil unless @pending_events.size > 0
        changes = {
          :events => @pending_events.dup,
          :aggregate_id => @aggregate_id,
          :aggregate_type => self.class.name,
          :expecting_source_version => @source_version,
          :expecting_version => @pending_events.max\
          { |a, b| a.version <=> b.version }.version
        }
        try_extract_snapshot_into changes
        changes
      end

      Contract Validation::AggregateChanges => nil
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
        nil
      end

      Contract None => nil
      def commit
        @pending_events = []
        @source_version = @version
        if self.is_a? Snapshotable and self.send :should_reset_snapshot_countdown?
          self.send(:reset_countdown, 0)
        end
        nil
      end

      Contract Validation::Event => nil
      def raise_event(event)
        apply(event)
        update_dispatch_detail_for(event)
        @pending_events << event
        nil
      end

      Contract Validation::Event => nil
      def update_dispatch_detail_for(event)
        event.instance_variable_set(:@aggregate_id, @aggregate_id)
        event.instance_variable_set(:@version, @version)
        nil
      end

      Contract Validation::Event => nil
      def apply(event)
        dispatch_handler_for(event)
        self.send(:snapshot_countdown) if self.is_a? Snapshotable
        @version += 1
        nil
      end

      Contract Validation::Event => nil
      def dispatch_handler_for(event)
        target = retrieve_handler_for(event.class)
        self.send(target, event)
        nil
      end

      Contract Validation::TypeOfEvent => Symbol
      def retrieve_handler_for(event_type)
        @event_handler_cache[event_type] ||= begin
          stripped_event_type_name = event_type.to_s.demodulize.underscore
          "on_#{stripped_event_type_name}".to_sym
        end
      end
    end
  end
end
