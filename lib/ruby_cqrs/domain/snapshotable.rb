module RubyCqrs
  module Domain
    module Snapshotable
      def initialize
        @countdown_threshold = 30
        super
      end

    private
      def should_take_a_snapshot?
        @countdown_threshold <= 0
      end

      def snapshot_countdown
        @countdown_threshold-= 1
      end

      # the including domain object should implement these two methods
      def take_a_snapshot
        raise NotImplementedError
      end

      def apply_snapshot snapshot_object
        raise NotImplementedError
      end
    end
  end
end
