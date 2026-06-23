# frozen_string_literal: true

# Kestówv 0.5.0 - core/scheduler.rb
#
# Basic task scheduler.
# Registers scheduler features in the bit vector.

module Kestowv
  module Core
    module Scheduler
      @tasks   = []
      @running = false
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:scheduler)
          Boot.set_bit(:scheduler)
        end

        def add_task(task)
          @mutex.synchronize { @tasks << task }
        end

        def run
          @running = true
          Kestowv::Core::Klog.info("Scheduler started")

          while @running
            task = @mutex.synchronize { @tasks.shift }

            if task
              begin
                task.call
              rescue => e
                Kestowv::Core::Klog.error("Scheduler task failed: #{e.message}")
              end
            else
              sleep 0.01
            end
          end
        end

        def stop
          @running = false
          Kestowv::Core::Klog.info("Scheduler stopped")
        end

        def to_a
          {
            queued_tasks: @tasks.size,
            running:      @running
          }
        end

        def stats
          {
            feature: :scheduler,
            queued:  @tasks.size
          }
        end
      end
    end
  end
end