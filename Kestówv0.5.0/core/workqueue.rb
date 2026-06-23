# frozen_string_literal: true

# Kestówv 0.5.0 — core/workqueue.rb
#
# Work queue with priority and scheduler integration.

module Kestowv
  module Core
    module Workqueue

      @queue   = []
      @running = false
      @mutex   = Mutex.new

      class << self

        def register
          Boot.register(:core_workqueue)
          Boot.set_bit(:core_workqueue)
        end

        def enqueue(priority: :normal, &block)
          entry = { block: block, priority: priority, enqueued_at: Time.now }
          @mutex.synchronize { @queue << entry }
        end

        def run
          @running = true
          while @running
            entry = @mutex.synchronize { @queue.shift }

            if entry
              begin
                entry[:block].call
              rescue => e
                Klog.error("Workqueue job failed", error: e.message)
              end
            else
              sleep 0.05
            end
          end
        end

        def stop
          @running = false
        end

        def to_a
          @mutex.synchronize do
            {
              queued:  @queue.size,
              running: @running
            }
          end
        end

        def stats
          @mutex.synchronize do
            {
              feature: :core_workqueue,
              queued:  @queue.size
            }
          end
        end
      end
    end
  end
end

Kestowv::Config::Modules.register(
  :core_workqueue,
  __FILE__,
  feature: :workqueue
)
