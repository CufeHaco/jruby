# frozen_string_literal: true

# Kestówv 0.5.0 - proc/task.rb
#
# Basic task structure.
# Registers task features.

module Kestowv
  module Proc
    module Task
      @tasks    = {}
      @next_tid = 1
      @mutex    = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_task)
          Boot.set_bit(:proc_task)
        end

        def create(name, &block)
          @mutex.synchronize do
            tid = @next_tid
            @next_tid += 1
            @tasks[tid] = {
              name:       name,
              block:      block,
              state:      :ready,
              created_at: Time.now
            }
            tid
          end
        end

        def get(tid)
          @tasks[tid]
        end

        def active
          @tasks.keys
        end

        def to_a
          @tasks
        end

        def stats
          {
            feature: :proc_task,
            count:   @tasks.size
          }
        end
      end
    end
  end
end