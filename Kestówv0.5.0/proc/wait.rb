# frozen_string_literal: true

# Kestówv 0.5.0 - proc/wait.rb
#
# Process wait/zombie handling.
# Registers wait features.

module Kestowv
  module Proc
    module Wait
      @zombies = []
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_wait)
          Boot.set_bit(:proc_wait)
        end

        def add_zombie(pid)
          @mutex.synchronize { @zombies << pid }
        end

        def reap
          @mutex.synchronize { @zombies.shift }
        end

        def to_a
          @zombies
        end

        def stats
          {
            feature: :proc_wait,
            zombies: @zombies.size
          }
        end
      end
    end
  end
end