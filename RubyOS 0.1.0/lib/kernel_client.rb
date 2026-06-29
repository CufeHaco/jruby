# frozen_string_literal: true

# RubyOS 0.1.0 — lib/kernel_client.rb
#
# Socket bridge to the Kestowv kernel. Same wire protocol cli/shell.rb
# uses: {"cmd"=>,"args"=>} request / {"ok"=>,"data"|"error"=>} response,
# MessagePack-framed over a UNIXSocket.

require 'socket'
require 'msgpack'

module KernelClient
  class << self
    def connect(sock_path)
      sock_path ||= abort("Usage: pid1.rb <socket_path>")
      tries = 0
      begin
        @sock = UNIXSocket.new(sock_path)
      rescue Errno::ENOENT, Errno::ECONNREFUSED
        tries += 1
        if tries < 75
          sleep 0.2
          retry
        end
        abort("Cannot connect to #{sock_path}")
      end
      @unpacker = MessagePack::Unpacker.new
      self
    end

    def request(cmd, args = [])
      @sock.write(MessagePack.pack({ "cmd" => cmd, "args" => args }))
      @sock.flush
      read_response
    end

    def close
      @sock&.close
    rescue IOError
      nil
    end

    def print_kernel_response(resp)
      unless resp
        puts "kernel disconnected."
        return
      end

      if resp["ok"]
        data = resp["data"]
        case data
        when Array
          data.each { |row| puts row.is_a?(Hash) ? row.map { |k, v| "#{k}=#{v}" }.join("  ") : row.to_s }
        when Hash
          data.each { |k, v| puts "#{k}: #{v}" }
        else
          puts data
        end
      else
        puts "error: #{resp['error']}"
      end
    end

    private

    def read_response
      loop do
        chunk = @sock.readpartial(65536)
        @unpacker.feed_each(chunk) { |msg| return msg }
      end
    rescue EOFError, Errno::EPIPE, IOError
      nil
    end
  end
end
