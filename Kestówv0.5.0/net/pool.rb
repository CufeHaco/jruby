# frozen_string_literal: true

# Kestówv 0.5.0 - net/pool.rb
#
# Socket/connection pool simulation.
# Registers pool features.

module Kestowv
  module Net
    module Pool
      @pools = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:net_pool)
          Boot.set_bit(:net_pool)
        end

        def create(name, size)
          @mutex.synchronize do
            @pools[name] = { size: size, in_use: 0 }
          end
        end

        def to_a
          @pools
        end

        def stats
          {
            feature: :net_pool,
            pools: @pools.size
          }
        end
      end
    end
  end
end