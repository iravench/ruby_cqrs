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

      def take_a_snapshot
        raise NotImplementedError.new 'implment take_a_snapshot method in your aggregate'
      end

      def apply_snapshot snapshot_object
        raise NotImplementedError.new 'implment apply_snapshot method in your aggregate'
      end
    end
  end
end
