# frozen_string_literal: true

# Kestówv 0.5.0 — core/klog.rb
#
# Kernel logging service.
# Ring buffer with levels, structured output, and Boot integration.

module Kestowv
  module Core
    module Klog

      @buffer   = []
      @max_size = 1024
      @level    = :info
      @mutex    = Mutex.new

      LEVELS = {
        debug: 0,
        info:  1,
        warn:  2,
        error: 3
      }.freeze

      class << self

        def register
          Boot.register(:klog)
          Boot.set_bit(:klog)
        end

        def level=(new_level)
          @mutex.synchronize { @level = new_level.to_sym }
        end

        def level
          @mutex.synchronize { @level }
        end

        def log(level, message, **context)
          lvl = level.to_sym
          return if LEVELS[lvl] < LEVELS[@level]

          entry = {
            time:    Time.now,
            level:   lvl,
            message: message,
            context: context
          }

          @mutex.synchronize do
            @buffer << entry
            @buffer.shift if @buffer.size > @max_size
          end

          # Also emit to stdout in development / when not quiet
          unless Boot.config.quiet
            prefix = lvl.to_s.upcase.ljust(5)
            puts "[KLOG] #{prefix} #{message}#{context.empty? ? '' : ' ' + context.inspect}"
          end
        end

        def debug(msg, **ctx) = log(:debug, msg, **ctx)
        def info(msg,  **ctx) = log(:info,  msg, **ctx)
        def warn(msg,  **ctx) = log(:warn,  msg, **ctx)
        def error(msg, **ctx) = log(:error, msg, **ctx)

        def recent(count = 50)
          @mutex.synchronize { @buffer.last(count).dup }
        end

        def clear
          @mutex.synchronize { @buffer.clear }
        end

        def to_a
          @mutex.synchronize { @buffer.dup }
        end

        def stats
          @mutex.synchronize do
            {
              size:     @buffer.size,
              max_size: @max_size,
              level:    @level,
              feature:  :klog
            }
          end
        end
      end
    end
  end
end

Kestowv::Config::Modules.register(
  :core_klog,
  __FILE__,
  feature: :klog
)
