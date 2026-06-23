# frozen_string_literal: true

# Kestówv 0.5.0 — core/signals.rb
#
# Signal handling with registration and dispatch.

module Kestowv
  module Core
    module Signals

      @handlers = {}
      @mutex    = Mutex.new

      class << self

        def register
          Boot.register(:core_signals)
          Boot.set_bit(:core_signals)
        end

        def register_signal(signal, &block)
          @mutex.synchronize { @handlers[signal] = block }
        end

        def dispatch(signal, *args)
          handler = @mutex.synchronize { @handlers[signal] }
          handler&.call(*args)
        end

        def to_a
          @mutex.synchronize { @handlers.keys.dup }
        end

        def stats
          @mutex.synchronize do
            {
              feature:  :core_signals,
              handlers: @handlers.size
            }
          end
        end
      end
    end
  end
end

Kestowv::Config::Modules.register(
  :core_signals,
  __FILE__,
  feature: :signals
)
