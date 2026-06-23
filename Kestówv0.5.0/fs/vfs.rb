# frozen_string_literal: true

# Kestówv 0.5.0 - fs/vfs.rb
#
# Virtual File System core.
# Registers VFS features.

module Kestowv
  module Fs
    module Vfs
      @mounts = {}
      @mutex  = Mutex.new

      class << self
        def register_features
          Boot.register(:fs_vfs)
          Boot.set_bit(:fs_vfs)
        end

        def mount(path, superblock)
          @mutex.synchronize { @mounts[path] = superblock }
        end

        def unmount(path)
          @mutex.synchronize { @mounts.delete(path) }
        end

        def lookup(path)
          @mounts[path]
        end

        def to_a
          @mounts.keys
        end

        def stats
          {
            feature: :fs_vfs,
            mounts:  @mounts.size
          }
        end
      end
    end
  end
end