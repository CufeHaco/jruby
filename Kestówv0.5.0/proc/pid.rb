# frozen_string_literal: true

# Kestówv 0.5.0 - proc/pid.rb
#
# PID management (refined).
# Registers PID features.

module Kestowv
  module Proc
    module Pid
      @next_pid = 1
      @pids     = {}
      @mutex    = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_pid)
          Boot.set_bit(:proc_pid)
        end

        def allocate
          @mutex.synchronize do
            pid = @next_pid
            @next_pid += 1
            @pids[pid] = { state: :allocated }
            pid
          end
        end

        def release(pid)
          @mutex.synchronize { @pids.delete(pid) }
        end

        def active
          @pids.keys
        end

        def to_a
          @pids.keys
        end

        def stats
          {
            feature: :proc_pid,
            active:  @pids.size
          }
        end
      end
    end
  end
end