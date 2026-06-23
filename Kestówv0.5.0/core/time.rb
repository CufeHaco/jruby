# frozen_string_literal: true

# Kestówv 0.5.0 - core/time.rb
#
# Time and jiffies tracking.
# Registers time features in the bit vector.

module Kestowv
  module Core
    module Time
      @jiffies    = 0
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @mutex      = Mutex.new

      class << self
        def register_features
          Boot.register(:time_jiffies)
          Boot.set_bit(:time_jiffies)
        end

        def tick
          @mutex.synchronize { @jiffies += 1 }
        end

        def jiffies
          @jiffies
        end

        def uptime
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
        end

        def to_a
          {
            jiffies:        @jiffies,
            uptime_seconds: uptime
          }
        end

        def stats
          {
            jiffies:        @jiffies,
            feature:        :time_jiffies
          }
        end
      end
    end
  end
end