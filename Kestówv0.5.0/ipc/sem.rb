# frozen_string_literal: true

# Kestówv 0.5.0 - ipc/sem.rb
#
# Semaphore simulation.
# Registers semaphore features.

module Kestowv
  module Ipc
    module Sem
      @sems  = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:ipc_sem)
          Boot.set_bit(:ipc_sem)
        end

        def create(key, value)
          @mutex.synchronize { @sems[key] = value }
        end

        def wait(key)
          @mutex.synchronize do
            # Spin until available — real impl would block/yield
            @sems[key] -= 1 if @sems[key] > 0
          end
        end

        def post(key)
          @mutex.synchronize { @sems[key] += 1 }
        end

        def to_a
          @sems
        end

        def stats
          {
            feature: :ipc_sem,
            count:   @sems.size
          }
        end
      end
    end
  end
end