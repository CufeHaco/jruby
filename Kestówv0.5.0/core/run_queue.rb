# frozen_string_literal: true

# Kestówv 0.5.0 — core/run_queue.rb
#
# Per-CPU run queue.
# FIFO policy by default — Scheduler layer applies priority ordering.
# dequeue uses a timeout-based wait so the scheduler loop can check
# stop conditions and handle idle without busy-polling.

module Kestowv
  module Core
    class RunQueue

      IDLE_TIMEOUT = 0.01   # 10ms idle wait — balances latency vs CPU burn

      attr_reader :cpu_id

      def initialize(cpu_id)
        @cpu_id   = cpu_id
        @queue    = []
        @mutex    = Mutex.new
        @cv       = ConditionVariable.new
        @stats    = { enqueued: 0, dequeued: 0, removed: 0 }
      end

      # Enqueue a task. No-op if already present (idempotent).
      def enqueue(task)
        @mutex.synchronize do
          return false if @queue.include?(task)
          @queue << task
          @stats[:enqueued] += 1
          @cv.signal
          true
        end
      end

      # Dequeue the next task.
      # Returns nil after IDLE_TIMEOUT if queue is empty —
      # lets the scheduler loop check @running and handle idle work.
      def dequeue
        @mutex.synchronize do
          if @queue.empty?
            @cv.wait(@mutex, IDLE_TIMEOUT)
          end
          task = @queue.shift
          @stats[:dequeued] += 1 if task
          task
        end
      end

      # Remove a specific task (e.g. on block or kill).
      def remove(task)
        @mutex.synchronize do
          removed = @queue.delete(task)
          @stats[:removed] += 1 if removed
          !removed.nil?
        end
      end

      # Move task to front — for high-priority wakeup (SIGCONT, unblock).
      def prioritize(task)
        @mutex.synchronize do
          @queue.delete(task)
          @queue.unshift(task)
          @cv.signal
        end
      end

      def empty?
        @mutex.synchronize { @queue.empty? }
      end

      def size
        @mutex.synchronize { @queue.size }
      end

      def include?(task)
        @mutex.synchronize { @queue.include?(task) }
      end

      def to_a
        @mutex.synchronize { @queue.dup }
      end

      def stats
        @mutex.synchronize do
          @stats.merge(cpu_id: @cpu_id, depth: @queue.size)
        end
      end

      def to_s
        "#<RunQueue cpu=#{@cpu_id} depth=#{size}>"
      end
    end
  end
end

Kestowv::Config::Modules.register(
  :core_run_queue,
  __FILE__,
  feature:    :scheduler,
  depends_on: [:proc_task]
)
