# frozen_string_literal: true

# Kestówv 0.5.0 - proc/env.rb
#
# Process environment variables.
# Registers env features.

module Kestowv
  module Proc
    module Env
      @envs = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_env)
          Boot.set_bit(:proc_env)
        end

        def set(pid, key, value)
          @mutex.synchronize do
            @envs[pid] ||= {}
            @envs[pid][key] = value
          end
        end

        def get(pid, key)
          @envs.dig(pid, key)
        end

        def to_a
          @envs
        end

        def stats
          {
            feature: :proc_env,
            processes: @envs.size
          }
        end
      end
    end
  end
end