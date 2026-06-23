# frozen_string_literal: true

# Kestówv 0.5.0 - core/workqueue.rb
#
# Work queue for deferred tasks.
# Registers workqueue as a feature.

module Kestowv
  module Core
    module Workqueue
      @queue   = []
      @running = false
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:core_workqueue)
          Boot.set_bit(:core_workqueue)
        end

        def enqueue(&block)
          @mutex.synchronize { @queue << block }
        end

        def run
          @running = true
          while @running
            job = @mutex.synchronize { @queue.shift }

            if job
              begin
                job.call
              rescue => e
                Kestowv::Core::Klog.error("Workqueue job failed: #{e.message}")
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
          {
            queued:  @queue.size,
            running: @running
          }
        end

        def stats
          {
            feature: :core_workqueue,
            queued:  @queue.size
          }
        end
      end
    end
  end
end