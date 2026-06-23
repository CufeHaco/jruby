# frozen_string_literal: true

# Kestówv 0.5.0 - debug/console.rb
#
# Interactive debug console.
# Registers console as a feature.

module Kestowv
  module Debug
    module Console
      @commands = {}

      class << self
        def register_features
          Boot.register(:debug_console)
          Boot.set_bit(:debug_console)
        end

        def register_command(name, &block)
          @commands[name.to_sym] = block
        end

        def execute(command, *args)
          cmd = command.to_sym
          if @commands.key?(cmd)
            @commands[cmd].call(*args)
          else
            Kestowv::Core::Klog.warn("Unknown console command: #{command}")
          end
        end

        def available_commands
          @commands.keys
        end

        def to_a
          {
            commands: available_commands,
            feature:  :debug_console
          }
        end
      end
    end
  end
end