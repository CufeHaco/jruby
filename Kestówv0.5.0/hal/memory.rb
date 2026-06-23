# frozen_string_literal: true

# Kestówv 0.5.0 - hal/memory.rb
#
# Memory hardware abstraction.
# Registers memory features.

module Kestowv
  module Hal
    module Memory
      @total = 1024 * 1024 * 1024  # 1GB default
      @used  = 0
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:hal_memory)
          Boot.set_bit(:hal_memory)
        end

        def total
          @total
        end

        def used
          @used
        end

        def allocate(size)
          @mutex.synchronize do
            return false unless @used + size <= @total
            @used += size
            true
          end
        end

        def free(size)
          @mutex.synchronize { @used -= size if @used >= size }
        end

        def to_a
          {
            total: @total,
            used:  @used
          }
        end

        def stats
          {
            feature:       :hal_memory,
            usage_percent: (@used.to_f / @total * 100).round(2)
          }
        end
      end
    end
  end
end