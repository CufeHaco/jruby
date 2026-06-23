# frozen_string_literal: true

# Kestówv 0.5.0 - ipc/rpc.rb
#
# RPC simulation (refined).
# Registers RPC features.

module Kestowv
  module Ipc
    module Rpc
      @methods = {}
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:ipc_rpc)
          Boot.set_bit(:ipc_rpc)
        end

        def register(name, &block)
          @mutex.synchronize { @methods[name] = block }
        end

        def call(name, *args)
          @methods[name]&.call(*args)
        end

        def to_a
          @methods.keys
        end

        def stats
          {
            feature: :ipc_rpc,
            methods: @methods.size
          }
        end
      end
    end
  end
end