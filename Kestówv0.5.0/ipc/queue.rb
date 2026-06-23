# frozen_string_literal: true

# Kestówv 0.5.0 - ipc/queue.rb
#
# Generic message queue.
# Registers queue features.

module Kestowv
  module Ipc
    module Queue
      @queues = {}
      @mutex  = Mutex.new

      class << self
        def register_features
          Boot.register(:ipc_queue)
          Boot.set_bit(:ipc_queue)
        end

        def create(key)
          @mutex.synchronize { @queues[key] ||= [] }
        end

        def enqueue(key, item)
          @mutex.synchronize { @queues[key] << item }
        end

        def dequeue(key)
          @mutex.synchronize { @queues[key]&.shift }
        end

        def to_a
          @queues.keys
        end

        def stats
          {
            feature: :ipc_queue,
            queues:  @queues.size
          }
        end
      end
    end
  end
end