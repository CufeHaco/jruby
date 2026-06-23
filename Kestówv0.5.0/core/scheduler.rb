# frozen_string_literal: true

# Kestówv 0.5.0 — core/scheduler.rb
#
# Basic task scheduler with policy hooks.
# Integrates with Tune profiles and Boot bit tracking.

module Kestowv
  module Core
    module Scheduler

      @tasks   = []
      @running = false
      @policy  = :fair
      @mutex   = Mutex.new

      class << self

        def register
          Boot.register(:scheduler)
          Boot.set_bit(:scheduler)
        end

        # Set scheduling policy (integrated with Tune)
        def policy=(new_policy)
          @mutex.synchronize { @policy = new_policy.to_sym }
        end

        def policy
          @mutex.synchronize { @policy }
        end

        def add_task(task, priority: :normal)
          entry = { task: task, priority: priority, added_at: Time.now }
          @mutex.synchronize { @tasks << entry }
        end

        def run
          @running = true
          Klog.info("Scheduler started", policy: @policy)

          while @running
            entry = @mutex.synchronize { @tasks.shift }

            if entry
              begin
                entry[:task].call
              rescue => e
                Klog.error("Scheduler task failed", error: e.message)
                Boot.handle_error(e, { component: :scheduler })
              end
            else
              # Yield based on current policy
              sleep(policy == :realtime ? 0.001 : 0.01)
            end
          end
        end

        def stop
          @running = false
          Klog.info("Scheduler stopped")
        end

        def to_a
          @mutex.synchronize do
            {
              queued:  @tasks.size,
              running: @running,
              policy:  @policy
            }
          end
        end

        def stats
          @mutex.synchronize do
            {
              feature: :scheduler,
              queued:  @tasks.size,
              policy:  @policy
            }
          end
        end
      end
    end
  end
end

Kestowv::Config::Modules.register(
  :core_scheduler,
  __FILE__,
  feature: :scheduler
)
