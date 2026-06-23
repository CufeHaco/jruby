# frozen_string_literal: true

# Kestówv 0.5.0 — mm/page.rb
#
# Physical page frame abstraction.
# Represents one physical memory page (default 4KB).
# Inherits identity, refcount, and lifecycle from KObject.

module Kestowv
  module Mm
    class Page < Kestowv::Core::KObject

      attr_reader :pfn, :size

      # Page Frame states — mirrors Linux page lifecycle.
      STATES = %i[free allocated reserved].freeze

      def initialize(pfn:, size: 4096, state: :free)
        raise ArgumentError, "Unknown page state: #{state}" unless STATES.include?(state)
        raise ArgumentError, "pfn must be non-negative Integer" unless pfn.is_a?(Integer) && pfn >= 0

        super(type_tag: :page)

        @pfn        = pfn
        @size       = size
        @state      = state
        @dirty      = false
        @referenced = false

        Boot.register(page_bit)
        Boot.set_bit(page_bit) if @state == :allocated
      end

      # --------------------------------------------------------
      # STATE MANAGEMENT
      # All mutations go through @mutex (inherited from KObject).
      # --------------------------------------------------------

      def allocate!
        changed = @mutex.synchronize do
          next false unless @state == :free
          @state      = :allocated
          @dirty      = false
          @referenced = true
          true
        end
        Boot.set_bit(page_bit) if changed
        changed
      end

      def free!
        changed = @mutex.synchronize do
          next false unless @state == :allocated
          @state      = :free
          @dirty      = false
          @referenced = false
          true
        end
        Boot.clear_bit(page_bit) if changed
        changed
      end

      def reserve!
        changed = @mutex.synchronize do
          next false if @state == :reserved
          @state = :reserved
          true
        end
        Boot.set_bit(page_bit) if changed
        changed
      end

      def mark_dirty
        @mutex.synchronize { @dirty = true }
        self
      end

      def mark_referenced
        @mutex.synchronize { @referenced = true }
        self
      end

      def clear_referenced
        @mutex.synchronize { @referenced = false }
        self
      end

      # --------------------------------------------------------
      # QUERY — all reads through @mutex for consistency
      # --------------------------------------------------------

      def state
        @mutex.synchronize { @state }
      end

      def dirty?
        @mutex.synchronize { @dirty }
      end

      def referenced?
        @mutex.synchronize { @referenced }
      end

      def free?
        @mutex.synchronize { @state == :free }
      end

      def allocated?
        @mutex.synchronize { @state == :allocated }
      end

      def reserved?
        @mutex.synchronize { @state == :reserved }
      end

      # --------------------------------------------------------
      # LIFECYCLE OVERRIDE
      # KObject#destroy clears the kobject bit — we also clear
      # the page-specific bit and free state.
      # --------------------------------------------------------

      def destroy
        @mutex.synchronize do
          @state      = :free
          @dirty      = false
          @referenced = false
        end
        Boot.clear_bit(page_bit)
        super
      end

      # --------------------------------------------------------
      # INTROSPECTION
      # --------------------------------------------------------

      def to_h
        @mutex.synchronize do
          super.merge(
            pfn:        @pfn,
            size:       @size,
            state:      @state,
            dirty:      @dirty,
            referenced: @referenced
          )
        end
      end

      def to_s
        "#<Page pfn=#{@pfn} state=#{state} size=#{@size} rc=#{refcount}>"
      end

      private

      def page_bit
        :"mm_page_#{@pfn}"
      end
    end
  end
end

# --------------------------------------------------------
# AUTO-REGISTER
# --------------------------------------------------------
Kestowv::Config::Modules.register(
  :mm_page,
  __FILE__,
  feature:    :mm_page,
  depends_on: [:core_kobject, :hal_memory]
)
