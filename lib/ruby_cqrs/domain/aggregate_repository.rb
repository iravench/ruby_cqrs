require 'active_support/inflector'
require_relative '../guid'

module RubyCqrs
  class AggregateNotFound < Error; end
  class AggregateConcurrencyError < Error; end
  class AggregateInstanceDuplicatedError < Error; end

  module Domain
    class AggregateRepository
      include RubyCqrs::Data::Decodable

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
        try_decode_from state
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
          aggregate_change = aggregate.send(:get_changes)
          next if aggregate_change.nil?
          try_encode_from aggregate_change
          product << aggregate_change
        end
        to_return
      end

      def try_decode_from state
        state[:snapshot] = decode_snapshot_state_from state[:snapshot]\
          if state.has_key? :snapshot

        state[:events].map! { |event_record| decode_event_from event_record }\
          if state[:events].size > 0
      end

      def decode_snapshot_state_from snapshot_record
        snapshot_state = try_decode snapshot_record[:state_type], snapshot_record[:data]
        { :state => snapshot_state, :version => snapshot_record[:version] }
      end

      def decode_event_from event_record
        decoded_event = try_decode event_record[:event_type], event_record[:data]
        decoded_event.instance_variable_set(:@aggregate_id, event_record[:aggregate_id])
        decoded_event.instance_variable_set(:@version, event_record[:version])
        decoded_event
      end

      def try_encode_from change
        if change.has_key? :snapshot
          encoded_snapshot = encode_data_from change[:snapshot][:state]
          change[:snapshot] = { :state_type => change[:snapshot][:state_type],
                                :version => change[:snapshot][:version],
                                :data => encoded_snapshot }
        end

        if change[:events].size > 0
          change[:events].map! { |event|
            { :data => encode_data_from(event),
              :aggregate_id => event.aggregate_id,
              :event_type => event.class.name,
              :version => event.version }
          }
        end
      end

      def encode_data_from obj
        data = obj
        data = data.try_encode if data.is_a? RubyCqrs::Data::Encodable
        data
      end
    end
  end
end
