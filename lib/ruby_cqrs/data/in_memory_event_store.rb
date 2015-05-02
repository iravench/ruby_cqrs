require 'contracts'
require_relative '../contracts'

module RubyCqrs
  module Data
    class InMemoryEventStore
      include EventStore
      include Contracts
      include Contracts::Modules

      Contract None => Any
      def initialize
        @aggregate_store = {}
        @event_store = {}
        @snapshot_store = {}
      end

      Contract Validation::AggregateId, Any\
               => Or[Validation::SerializedAggregateState,\
                     Validation::SerializedAggregateStateWithSnapshot]
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

      Contract Or[ArrayOf[Validation::SerializedAggregateState],\
                  ArrayOf[Validation::SerializedAggregateStateWithSnapshot]], Any => nil
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
