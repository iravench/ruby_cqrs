module RubyCqrs
  module Data
    class EventStore
      def load_by guid, command_context
        raise NotImplementedError
      end

      def save changes, command_context
        raise NotImplementedError
      end
    end
  end
end
