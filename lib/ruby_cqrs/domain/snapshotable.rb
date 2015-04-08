module RubyCqrs
  module Domain
    module Snapshotable
      def initialize
        if self.class.const_defined? :SNAPSHOT_THRESHOLD
          @snapshot_threshold = self.class.const_get(:SNAPSHOT_THRESHOLD)
        else
          @snapshot_threshold = 30
        end
        @snapshot_threshold = 30 if @snapshot_threshold <= 0
        @countdown = @snapshot_threshold
        @reset_snapshot_countdown_flag = false
        super
      end

    private
      def should_take_a_snapshot?
        @countdown <= 0
      end

      def snapshot_countdown
        @countdown -= 1
      end

      def reset_countdown loaded_event_count
        @countdown = @snapshot_threshold - loaded_event_count
        @reset_snapshot_countdown_flag = false
      end

      def should_reset_snapshot_countdown?
        @reset_snapshot_countdown_flag
      end

      def set_snapshot_taken
        @reset_snapshot_countdown_flag = true
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
