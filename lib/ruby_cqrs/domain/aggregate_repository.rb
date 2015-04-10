require 'active_support/inflector'
require_relative '../guid'

module RubyCqrs
  class AggregateNotFound < Error; end
  class AggregateConcurrencyError < Error; end
  class AggregateInstanceDuplicatedError < Error; end

  module Domain
    class AggregateRepository
      def find_by aggregate_id
        raise ArgumentError if aggregate_id.nil?
        raise ArgumentError unless Guid.validate? aggregate_id

        state = @event_store.load_by(aggregate_id, @command_context)
        raise AggregateNotFound if (state.nil? or state[:aggregate_type].nil? or\
                                    ((state[:events].nil? or state[:events].empty?) and state[:snapshot].nil?))

        create_instance_from state
      end

      def save one_or_many_aggregate
        raise ArgumentError if one_or_many_aggregate.nil?
        return delegate_persistence_of [ one_or_many_aggregate ] if one_or_many_aggregate.is_a? Aggregate

        raise ArgumentError unless one_or_many_aggregate.is_a? Enumerable and one_or_many_aggregate.size > 0
        delegate_persistence_of one_or_many_aggregate
      end

    private
      def initialize event_store, command_context
        raise ArgumentError unless event_store.is_a? Data::EventStore
        @event_store = event_store
        @command_context = command_context
      end

      def create_instance_from state
        instance = state[:aggregate_type].constantize.new
        instance.send(:load_from, state)
        instance
      end

      def delegate_persistence_of aggregates
        verify_uniqueness_of aggregates

        changes = prep_changes_for(aggregates)
        if changes.size > 0
          @event_store.save changes, @command_context
          aggregates.each do |aggregate|
            aggregate.send(:commit)
          end
        end

        nil
      end

      def verify_uniqueness_of aggregates
        uniq_array =  aggregates.uniq { |aggregate| aggregate.aggregate_id }
        raise AggregateInstanceDuplicatedError unless uniq_array.size == aggregates.size
      end

      def prep_changes_for aggregates
        to_return = []
        aggregates.inject(to_return) do |product, aggregate|
          raise ArgumentError unless aggregate.is_a? Aggregate
          pending_changes = aggregate.send(:get_changes)
          next if pending_changes.nil?
          product << pending_changes
        end
        to_return
      end
    end
  end
end
