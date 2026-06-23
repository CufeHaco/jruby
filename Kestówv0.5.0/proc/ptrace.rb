# frozen_string_literal: true

# Kestówv 0.5.0 - proc/ptrace.rb
#
# Process tracing simulation.
# Registers ptrace features.

module Kestowv
  module Proc
    module Ptrace
      @traced = {}
      @mutex  = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_ptrace)
          Boot.set_bit(:proc_ptrace)
        end

        def trace(pid)
          @mutex.synchronize { @traced[pid] = true }
        end

        def traced?(pid)
          @traced[pid] == true
        end

        def to_a
          @traced.keys
        end

        def stats
          {
            feature: :proc_ptrace,
            traced:  @traced.size
          }
        end
      end
    end
  end
end