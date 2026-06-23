# frozen_string_literal: true

# Kestówv 0.5.0 - proc/pid.rb
#
# PID allocation and management.
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
            @pids[pid] = { state: :allocated, created_at: Time.now }
            pid
          end
        end

        def release(pid)
          @mutex.synchronize { @pids.delete(pid) }
        end

        def active_pids
          @pids.keys
        end

        def to_a
          @pids
        end

        def stats
          {
            feature:   :proc_pid,
            allocated: @pids.size,
            next_pid:  @next_pid
          }
        end
      end
    end
  end
end