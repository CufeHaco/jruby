# frozen_string_literal: true

# Kestówv 0.5.0 - ipc/msg.rb
#
# Message queue simulation.
# Registers message queue features.

module Kestowv
  module Ipc
    module Msg
      @queues = {}
      @mutex  = Mutex.new

      class << self
        def register_features
          Boot.register(:ipc_msg)
          Boot.set_bit(:ipc_msg)
        end

        def create(key)
          @mutex.synchronize { @queues[key] ||= [] }
        end

        # Avoid collision with Kernel#send
        def enqueue(key, message)
          @mutex.synchronize { @queues[key] << message }
        end

        def receive(key)
          @mutex.synchronize { @queues[key]&.shift }
        end

        def to_a
          @queues
        end

        def stats
          {
            feature: :ipc_msg,
            queues:  @queues.size
          }
        end
      end
    end
  end
end