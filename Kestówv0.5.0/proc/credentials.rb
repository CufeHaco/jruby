# frozen_string_literal: true

# Kestówv 0.5.0 - proc/credentials.rb
#
# Process credentials (uid/gid).
# Registers credentials features.

module Kestowv
  module Proc
    module Credentials
      @creds = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_credentials)
          Boot.set_bit(:proc_credentials)
        end

        def set(pid, uid, gid)
          @mutex.synchronize do
            @creds[pid] = { uid: uid, gid: gid }
          end
        end

        def get(pid)
          @creds[pid]
        end

        def to_a
          @creds
        end

        def stats
          {
            feature:   :proc_credentials,
            processes: @creds.size
          }
        end
      end
    end
  end
end