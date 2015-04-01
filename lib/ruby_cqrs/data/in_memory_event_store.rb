module RubyCqrs
  module Data
    class InMemoryEventStore < EventStore
      def load_by guid, command_context
      end

      def save changes, command_context
      end
    end
  end
end
