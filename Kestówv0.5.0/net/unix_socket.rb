# frozen_string_literal: true

# Kestówv 0.5.0 - net/unix_socket.rb
#
# Unix domain socket.
# Registers unix socket features.

module Kestowv
  module Net
    module UnixSocket
      @sockets = {}
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:net_unix_socket)
          Boot.set_bit(:net_unix_socket)
        end

        def create(path)
          @mutex.synchronize do
            @sockets[path] = { path: path, state: :closed }
          end
        end

        def close(path)
          @mutex.synchronize { @sockets.delete(path) }
        end

        def to_a
          @sockets.keys
        end

        def stats
          {
            feature: :net_unix_socket,
            count:   @sockets.size
          }
        end
      end
    end
  end
end