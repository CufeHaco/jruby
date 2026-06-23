# frozen_string_literal: true

# Kestówv 0.5.0 - hal/interrupts.rb
#
# Interrupt handling abstraction.
# Registers interrupt features.

module Kestowv
  module Hal
    module Interrupts
      @handlers = {}
      @mutex    = Mutex.new

      class << self
        def register_features
          Boot.register(:hal_interrupts)
          Boot.set_bit(:hal_interrupts)
        end

        def register(irq, &block)
          @mutex.synchronize { @handlers[irq] = block }
        end

        def handle(irq)
          @handlers[irq]&.call
        end

        def to_a
          @handlers.keys
        end

        def stats
          {
            feature:  :hal_interrupts,
            handlers: @handlers.size
          }
        end
      end
    end
  end
end