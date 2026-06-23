# frozen_string_literal: true

# Kestówv 0.5.0 - mm/physical.rb
#
# Physical memory management.
# Registers physical memory features.

module Kestowv
  module Mm
    module Physical
      @total = 1024 * 1024 * 1024  # 1GB default
      @used  = 0
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:mm_physical)
          Boot.set_bit(:mm_physical)
        end

        def allocate(size)
          @mutex.synchronize do
            return false unless @used + size <= @total
            @used += size
            true
          end
        end

        def free(size)
          @mutex.synchronize do
            @used -= size if @used >= size
          end
        end

        def usage
          @used
        end

        def total
          @total
        end

        def to_a
          {
            total: @total,
            used:  @used
          }
        end

        def stats
          {
            feature:       :mm_physical,
            usage_percent: (@used.to_f / @total * 100).round(2)
          }
        end
      end
    end
  end
end