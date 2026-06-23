# frozen_string_literal: true

# Kestówv 0.5.0 - mm/page_table.rb
#
# Page table management.
# Registers page table features.

module Kestowv
  module Mm
    module PageTable
      @tables = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:mm_page_table)
          Boot.set_bit(:mm_page_table)
        end

        def create(pid)
          @mutex.synchronize do
            @tables[pid] = {}
          end
        end

        def map(pid, vaddr, paddr)
          @mutex.synchronize do
            @tables[pid] ||= {}
            @tables[pid][vaddr] = paddr
          end
        end

        def to_a
          @tables
        end

        def stats
          {
            feature: :mm_page_table,
            processes: @tables.size
          }
        end
      end
    end
  end
end