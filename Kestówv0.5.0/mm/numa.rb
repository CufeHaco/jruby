# frozen_string_literal: true

# Kestówv 0.5.0 - mm/numa.rb
#
# NUMA topology simulation.
# Registers NUMA features.

module Kestowv
  module Mm
    module Numa
      @nodes = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:mm_numa)
          Boot.set_bit(:mm_numa)
        end

        def add_node(id, memory)
          @mutex.synchronize { @nodes[id] = { memory: memory } }
        end

        def to_a
          @nodes
        end

        def stats
          {
            feature: :mm_numa,
            nodes:   @nodes.size
          }
        end
      end
    end
  end
end