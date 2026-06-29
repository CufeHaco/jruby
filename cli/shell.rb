# frozen_string_literal: true

# Kestówv 0.5.1 — cli/shell.rb
#
# CRuby interactive userspace shell.
# Launched by boot/cli_shell.rb — sends command requests to the Kestowv
# kernel (JRuby) over a Unix Domain Socket and prints the responses.
# Bidirectional MessagePack framing, unlike the one-way tk/tui dashboards.
#
# Do not run directly. Invoked as:
#   ruby cli/shell.rb <socket_path>

require 'socket'
require 'msgpack'

SOCK_PATH = ARGV[0] || abort("Usage: shell.rb <socket_path>")

# ── Connect to kernel (retry briefly — server may still be binding) ──────────
sock  = nil
tries = 0
begin
  sock = UNIXSocket.new(SOCK_PATH)
rescue Errno::ENOENT, Errno::ECONNREFUSED
  tries += 1
  if tries < 75
    sleep 0.2
    retry
  end
  abort("Cannot connect to #{SOCK_PATH}")
end

unpacker = MessagePack::Unpacker.new

def send_request(sock, cmd, args)
  sock.write(MessagePack.pack({ "cmd" => cmd, "args" => args }))
  sock.flush
end

def read_response(sock, unpacker)
  loop do
    chunk = sock.readpartial(65536)
    unpacker.feed_each(chunk) { |msg| return msg }
  end
rescue EOFError, Errno::EPIPE, IOError
  nil
end

def print_response(resp)
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

puts ""
puts "Kestówv 0.5.1 — CLI userspace shell"
puts "Connected to #{SOCK_PATH}"
puts "Type 'help' for commands, 'exit' to quit."
puts ""

loop do
  print "kestowv> "
  line = $stdin.gets
  break unless line

  line = line.strip
  next if line.empty?

  parts = line.split(/\s+/)
  cmd   = parts.shift
  args  = parts

  send_request(sock, cmd, args)
  resp = read_response(sock, unpacker)
  print_response(resp)

  break if %w[exit quit].include?(cmd) || resp.nil?
end

sock.close rescue nil
puts "bye."
