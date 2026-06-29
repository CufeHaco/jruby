# frozen_string_literal: true

# RubyOS 0.1.0 — bin/rubian.rb
#
# Rubian — the shell. Started by pid1.rb as the last init step, once
# every command method (whoami, ps, ls, ...) has already been loaded
# from bin/. Dispatches via respond_to?+send, not eval — every command
# is still a bare global method, same feel as Rubian 3.1.0, without
# evaluating arbitrary input.

module Rubian
  VERSION = "4.0.0"

  def self.start
    puts ""
    puts "RubyOS 0.1.0 — Rubian #{VERSION} shell"
    puts "Type 'help' for commands, 'exit' to quit."
    puts ""

    loop do
      print "rubian> "
      line = $stdin.gets
      break unless line

      line = line.strip
      next if line.empty?

      cmd, *args = line.split(/\s+/)
      break if %w[exit quit].include?(cmd)

      if respond_to?(cmd, true)
        send(cmd, *args)
      else
        puts "command not found: #{cmd}"
      end
    end

    KernelClient.close
    puts "bye."
  end
end
