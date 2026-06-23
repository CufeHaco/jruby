# frozen_string_literal: true

# Kestówv 0.5.0 - fs/tmpfs.rb
#
# Tmpfs (in-memory filesystem) simulation.
# Registers tmpfs features.

module Kestowv
  module Fs
    module Tmpfs
      @files = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:fs_tmpfs)
          Boot.set_bit(:fs_tmpfs)
        end

        def create_file(path, data = "")
          @mutex.synchronize { @files[path] = data }
        end

        def read(path)
          @files[path]
        end

        def to_a
          @files.keys
        end

        def stats
          {
            feature: :fs_tmpfs,
            files:   @files.size
          }
        end
      end
    end
  end
end