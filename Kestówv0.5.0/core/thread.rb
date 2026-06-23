# frozen_string_literal: true

# Kestówv 0.5.0 — core/thread.rb
#
# Thread management with KObject integration and scheduler awareness.

module Kestowv
  module Core
    module Thread

      @threads  = {}
      @next_tid = 1
      @mutex    = Mutex.new

      class << self

        def register
          Boot.register(:core_thread)
          Boot.set_bit(:core_thread)
        end

        def create(name: nil, &block)
          tid = allocate_tid

          kthread = KObject.new(type_tag: :thread)

          entry = {
            kobject:    kthread,
            thread:     ::Thread.new(&block),
            name:       name || "thread-#{tid}",
            state:      :running,
            created_at: Time.now
          }

          @mutex.synchronize { @threads[tid] = entry }

          Boot.set_bit(: