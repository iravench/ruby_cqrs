require 'active_support/inflector'
require_relative '../guid'

module RubyCqrs
  class AggregateNotFound < Error; end
  class AggregateConcurrencyError < Error; end
  class AggregateNotPersisted < Error; end

  module Domain
    class AggregateRepository
      def initialize event_store, command_context
        raise ArgumentError unless event_store.is_a? Data::EventStore
        @event_store = event_store
        @command_context = command_context
      end

      def find_by aggregate_id
        raise ArgumentError if aggregate_id.nil?
        raise ArgumentError unless Guid.validate? aggregate_id

        aggregate_type, events = @event_store.load_by(aggregate_id, @command_context)
        raise AggregateNotFound if (aggregate_type.nil? or events.nil? or events.empty?)

        create_instance_from aggregate_type, events
      end

      def save one_or_many_aggregate
        raise ArgumentError if one_or_many_aggregate.nil?
        return delegate_persistence_of [ one_or_many_aggregate ] if one_or_many_aggregate.is_a? AggregateBase

        raise ArgumentError unless one_or_many_aggregate.is_a? Enumerable and one_or_many_aggregate.size > 0
        delegate_persistence_of one_or_many_aggregate
      end

    private
      def create_instance_from aggregate_type, events
        instance = aggregate_type.constantize.new
        instance.send(:load_from, events)
        instance
      end

      def delegate_persistence_of aggregates
        changes = prep_changes_for(aggregates)
        if changes.size > 0
          @event_store.save changes, @command_context
          aggregates.each do |aggregate|
            aggregate.send(:commit)
          end
        end
        nil
      end

      def prep_changes_for aggregates
        to_return = []
        aggregates.inject(to_return) do |product, aggregate|
          raise ArgumentError unless aggregate.is_a? AggregateBase
          pending_changes = aggregate.send(:get_changes)
          next if pending_changes.nil?
          product << pending_changes
        end
        to_return
      end
    end
  end
end
