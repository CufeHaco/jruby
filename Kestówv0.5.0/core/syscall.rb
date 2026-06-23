# frozen_string_literal: true

# Kestówv 0.5.0 - core/syscall.rb
#
# System call interface simulation.
# Registers syscall features.

module Kestowv
  module Core
    module Syscall
      @handlers = {}
      @mutex    = Mutex.new

      class << self
        def register_features
          Boot.register(:core_syscall)
          Boot.set_bit(:core_syscall)
        end

        def register(number, &block)
          @mutex.synchronize { @handlers[number] = block }
        end

        def invoke(number, *args)
          @handlers[number]&.call(*args)
        end

        def to_a
          @handlers.keys
        end

        def stats
          {
            feature:  :core_syscall,
            handlers: @handlers.size
          }
        end
      end
    end
  end
end