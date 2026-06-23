# frozen_string_literal: true

# Kestówv 0.5.0 - core/thread.rb
#
# Thread management primitives.
# Registers thread features in the bit vector.

module Kestowv
  module Core
    module Thread
      @threads  = {}
      @next_tid = 1
      @mutex    = Mutex.new

      class << self
        def register_features
          Boot.register(:core_thread)
          Boot.set_bit(:core_thread)
        end

        def create(&block)
          @mutex.synchronize do
            tid = @next_tid
            @next_tid += 1
            @threads[tid] = {
              thread:     ::Thread.new(&block),
              created_at: Time.now
            }
            tid
          end
        end

        def join(tid)
          @threads[tid]&.[](:thread)&.join
        end

        def kill(tid)
          @threads[tid]&.[](:thread)&.kill
          @mutex.synchronize { @threads.delete(tid) }
        end

        def active
          @threads.keys
        end

        def to_a
          @threads.keys
        end

        def stats
          {
            feature: :core_thread,
            active:  @threads.size
          }
        end
      end
    end
  end
end