# frozen_string_literal: true

# Kestówv 0.5.0 - proc/limits.rb
#
# Resource limits.
# Registers limits features.

module Kestowv
  module Proc
    module Limits
      @limits = {}
      @mutex  = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_limits)
          Boot.set_bit(:proc_limits)
        end

        def set(pid, resource, soft, hard)
          @mutex.synchronize do
            @limits[pid] ||= {}
            @limits[pid][resource] = { soft: soft, hard: hard }
          end
        end

        def get(pid, resource)
          @limits.dig(pid, resource)
        end

        def to_a
          @limits
        end

        def stats
          {
            feature:   :proc_limits,
            processes: @limits.size
          }
        end
      end
    end
  end
end