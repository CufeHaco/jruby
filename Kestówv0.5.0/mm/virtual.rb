# frozen_string_literal: true

# Kestówv 0.5.0 - mm/virtual.rb
#
# Virtual memory management.
# Registers virtual memory features.

module Kestowv
  module Mm
    module Virtual
      @mappings = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:mm_virtual)
          Boot.set_bit(:mm_virtual)
        end

        def map(pid, start, size)
          @mutex.synchronize do
            @mappings[pid] ||= []
            @mappings[pid] << { start: start, size: size }
          end
        end

        def unmap(pid, start)
          @mutex.synchronize do
            @mappings[pid]&.reject! { |m| m[:start] == start }
          end
        end

        def to_a
          @mappings
        end

        def stats
          {
            feature: :mm_virtual,
            processes: @mappings.size
          }
        end
      end
    end
  end
end