# frozen_string_literal: true

# Kestówv 0.5.0 - core/signals.rb
#
# Signal handling primitives.
# Registers signal features.

module Kestowv
  module Core
    module Signals
      @handlers = {}
      @mutex    = Mutex.new

      class << self
        def register_features
          Boot.register(:core_signals)
          Boot.set_bit(:core_signals)
        end

        def register(signal, &block)
          @mutex.synchronize { @handlers[signal] = block }
        end

        # Avoid collision with Ruby's built-in Kernel#send
        def dispatch(signal, *args)
          @handlers[signal]&.call(*args)
        end

        def to_a
          @handlers.keys
        end

        def stats
          {
            feature:  :core_signals,
            handlers: @handlers.size
          }
        end
      end
    end
  end
end