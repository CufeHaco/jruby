# frozen_string_literal: true

# Kestówv 0.5.0 - fs/stat.rb
#
# File stat simulation.
# Registers stat features.
#
# Note: @stats (instance var) and .stats (introspection method) are
# intentionally distinct — the method reports on the registry, not itself.

module Kestowv
  module Fs
    module Stat
      @stats = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:fs_stat)
          Boot.set_bit(:fs_stat)
        end

        def set(ino, mode, size)
          @mutex.synchronize do
            @stats[ino] = { mode: mode, size: size }
          end
        end

        def get(ino)
          @stats[ino]
        end

        def to_a
          @stats
        end

        def stats
          {
            feature: :fs_stat,
            inodes:  @stats.size
          }
        end
      end
    end
  end
end