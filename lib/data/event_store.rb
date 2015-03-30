module RubyCqrs
  module Data
    class EventStore
      def load_by guid, context
       raise NotImplementedError
      end

      def save changes, context
       raise NotImplementedError
      end
    end
  end
end
