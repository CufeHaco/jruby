# frozen_string_literal: true

# Kestówv 0.5.0 — core/syscall.rb
#
# System call interface.
# Registration + dispatch table with Boot integration.

module Kestowv
  module Core
    module Syscall

      @handlers = {}
      @names    = {}
      @mutex    = Mutex.new

      # Basic syscall numbers (extend as the system grows)
      SYSCALLS = {
        read:        0,
        write:       1,
        open:        2,
        close:       3,
        fork:       57,
        execve:     59,
        exit:       60,
        getpid:     39,
        sched_yield: 24
      }.freeze

      class << self

        def register(name, number = nil, &block)
          key = name.to_sym
          num = number || SYSCALLS[key]

          @mutex.synchronize do
            @handlers[num] = block if block
            @names[key] = num
            Boot.register(: