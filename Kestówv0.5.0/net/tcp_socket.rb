# frozen_string_literal: true

# Kestówv 0.5.0 - net/tcp_socket.rb
#
# TCP socket.
# Registers TCP socket features.

module Kestowv
  module Net
    module TcpSocket
      @sockets = {}
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:net_tcp_socket)
          Boot.set_bit(:net_tcp_socket)
        end

        def create
          @mutex.synchronize do
            id = SecureRandom.hex(4)
            @sockets[id] = { state: :closed, local_port: nil, remote: nil }
            id
          end
        end

        def connect(id, host, port)
          @mutex.synchronize do
            if @sockets[id]
              @sockets[id][:state]  = :connected
              @sockets[id][:remote] = "#{host}:#{port}"
            end
          end
        end

        def close(id)
          @mutex.synchronize { @sockets.delete(id) }
        end

        def to_a
          @sockets.keys
        end

        def stats
          {
            feature: :net_tcp_socket,
            count:   @sockets.size
          }
        end
      end
    end
  end
end