# frozen_string_literal: true

# Kestówv 0.5.0 - proc/session.rb
#
# Session management.
# Registers session features.

module Kestowv
  module Proc
    module Session
      @sessions = {}
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_session)
          Boot.set_bit(:proc_session)
        end

        def create(sid)
          @mutex.synchronize do
            @sessions[sid] = { pgids: [] }
          end
        end

        def to_a
          @sessions
        end

        def stats
          {
            feature: :proc_session,
            sessions: @sessions.size
          }
        end
      end
    end
  end
end