require 'active_support/inflector'
require 'beefcake'

module RubyCqrs
  module Data
    module ProtobufableEvent
      def try_encode event
        return event.encode.to_s if event.is_a? Beefcake::Message
        event
      end

      def try_decode event_record
        event_type = event_record[:event_type].constantize
        return event_record[:data] unless event_type.include? Beefcake::Message
        decoded_event = event_type.decode event_record[:data]
        decoded_event.instance_variable_set(:@aggregate_id, event_record[:aggregate_id])
        decoded_event.instance_variable_set(:@version, event_record[:version])
        decoded_event
      end
    end
  end
end
