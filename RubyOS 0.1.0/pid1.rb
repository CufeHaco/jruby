# frozen_string_literal: true

# RubyOS 0.1.0 — pid1.rb
#
# Userspace entry point execed by Kestowv as PID 1. Boots the same way
# Kestowv::Init brings up the kernel: a step-sequenced load using the
# kernel's own Boot module, ending in a handoff to the shell (Rubian).
#
# Run: ruby pid1.rb <socket_path>

require_relative '../boot/boot'

module RubyOS
  module Init
    ROOT = __dir__

    class << self
      def boot(sock_path)
        step("Load lib/")           { Boot.load_directory(File.join(ROOT, "lib"), recursive: false) }
        step("Load bin/")           { Boot.load_directory(File.join(ROOT, "bin"), recursive: false) }
        step("Connect to kernel")   { KernelClient.connect(sock_path) }
        step("Start shell: Rubian") { Rubian.start }
      end

      private

      def step(label)
        yield
        warn "[Init] ✓ #{label}"
      rescue => e
        warn "[Init] ✗ #{label} FAILED: #{e.message}"
        raise
      end
    end
  end
end

RubyOS::Init.boot(ARGV[0]) if __FILE__ == $0
