# frozen_string_literal: true

# Kestówv 0.5.0 - mm/slab.rb
#
# Simple slab allocator simulation.
# Registers memory features.

module Kestowv
  module Mm
    module Slab
      @slabs = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:mm_slab)
          Boot.set_bit(:mm_slab)
        end

        def create_slab(name, object_size, count)
          @mutex.synchronize do
            @slabs[name] = {
              object_size: object_size,
              total:       count,
              free:        count
            }
          end
        end

        def allocate(name)
          @mutex.synchronize do
            slab = @slabs[name]
            return nil unless slab && slab[:free] > 0
            slab[:free] -= 1
            true
          end
        end

        def free(name)
          @mutex.synchronize do
            slab = @slabs[name]
            return false unless slab
            slab[:free] += 1 if slab[:free] < slab[:total]
            true
          end
        end

        def to_a
          @slabs
        end

        def stats
          {
            feature: :mm_slab,
            slabs:   @slabs.size
          }
        end
      end
    end
  end
end