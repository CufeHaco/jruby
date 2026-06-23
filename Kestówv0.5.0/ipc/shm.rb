# frozen_string_literal: true

# Kestówv 0.5.0 - ipc/shm.rb
#
# Shared memory simulation.
# Registers shared memory features.

module Kestowv
  module Ipc
    module Shm
      @segments = {}
      @mutex    = Mutex.new

      class << self
        def register_features
          Boot.register(:ipc_shm)
          Boot.set_bit(:ipc_shm)
        end

        def create(key, size)
          @mutex.synchronize do
            @segments[key] = { size: size, created_at: Time.now }
          end
        end

        def attach(key)
          @segments[key]
        end

        def detach(key)
          # Placeholder for real detachment logic
        end

        def to_a
          @segments
        end

        def stats
          {
            feature:  :ipc_shm,
            segments: @segments.size
          }
        end
      end
    end
  end
end