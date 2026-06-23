# frozen_string_literal: true

# Kestówv 0.5.0 - ipc/pipe.rb
#
# Pipe simulation.
# Registers pipe features.

module Kestowv
  module Ipc
    module Pipe
      @pipes = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:ipc_pipe)
          Boot.set_bit(:ipc_pipe)
        end

        def create
          id = SecureRandom.hex(4)
          @mutex.synchronize { @pipes[id] = [] }
          id
        end

        # Avoid collision with Kernel#puts / IO#write — name is fine here
        # but note: read/write shadow IO methods if mixed into IO context
        def write(id, data)
          @mutex.synchronize { @pipes[id] << data }
        end

        def read(id)
          @mutex.synchronize { @pipes[id]&.shift }
        end

        def to_a
          @pipes.keys
        end

        def stats
          {
            feature: :ipc_pipe,
            pipes:   @pipes.size
          }
        end
      end
    end
  end
end