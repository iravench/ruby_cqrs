require 'contracts'

module RubyCqrs
  module Validation
    include Contracts
    include Contracts::Modules

    class EventStore
      def self.valid? val
        val.is_a? RubyCqrs::Data::EventStore
      end
    end

    class Event
      def self.valid? val
        val.is_a? RubyCqrs::Domain::Event
      end
    end

    class TypeOfEvent
      def self.valid? val
        val < RubyCqrs::Domain::Event
      end
    end

    class Snapshot
      def self.valid? val
        val.is_a? RubyCqrs::Domain::Snapshot
      end
    end

    class Aggregate
      def self.valid? val
        val.is_a? RubyCqrs::Domain::Aggregate
      end
    end

    class AggregateId
      def self.valid? val
        RubyCqrs::Guid.validate? val
      end
    end

    AggregateChanges = ({ :events => ArrayOf[Event],
                          :aggregate_id => AggregateId,
                          :aggregate_type => String,
                          :expecting_source_version => Or[0, Pos],
                          :expecting_version => Pos })

    AggregateChangesWithSnapshot = ({\
                          :events => ArrayOf[Event],
                          :aggregate_id => AggregateId,
                          :aggregate_type => String,
                          :expecting_source_version => Or[0, Pos],
                          :expecting_version => Pos,
                          :snapshot => {\
                                 :state => Snapshot,
                                 :state_type => String,
                                 :version => Pos }})

    AggregateState = ({\
                          :aggregate_id => AggregateId,
                          :aggregate_type => String,
                          :events => ArrayOf[Event]})

    AggregateStateWithSnapshot = ({\
                        :aggregate_id => AggregateId,
                        :aggregate_type => String,
                        :snapshot => {\
                                 :state => Snapshot,
                                 :version => Pos },
                        :events => ArrayOf[Event]})

    SerializedAggregateState = ({\
                          :aggregate_id => AggregateId,
                          :aggregate_type => String,
                          :events => ArrayOf[{\
                                 :aggregate_id => AggregateId,
                                 :event_type => String,
                                 :version => Pos,
                                 :data => String }]})

    SerializedAggregateStateWithSnapshot = ({\
                        :aggregate_id => AggregateId,
                        :aggregate_type => String,
                        :snapshot => {\
                                 :state_type => String,
                                 :version => Pos,
                                 :data => String },
                        :events => ArrayOf[{\
                                 :aggregate_id => AggregateId,
                                 :event_type => String,
                                 :version => Pos,
                                 :data => String }]})
  end
end
