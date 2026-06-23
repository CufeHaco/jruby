# frozen_string_literal: true

# Kestówv 0.5.0 - core/klog.rb
#
# Kernel logging ring buffer.
# Registers logging as a bit vector feature.

module Kestowv
  module Core
    module Klog
      @buffer   = []
      @max_size = 1024
      @mutex    = Mutex.new

      class << self
        def register_feature
          Boot.register(:klog)
          Boot.set_bit(:klog)
        end

        def log(level, message)
          entry = {
            time:    Time.now,
            level:   level,
            message: message
          }

          @mutex.synchronize do
            @buffer << entry
            @buffer.shift if @buffer.size > @max_size
          end
        end

        def info(msg)  = log(:info,  msg)
        def warn(msg)  = log(:warn,  msg)
        def error(msg) = log(:error, msg)

        def recent(count = 50)
          @buffer.last(count)
        end

        def clear
          @mutex.synchronize { @buffer.clear }
        end

        def to_a
          @buffer
        end

        def stats
          {
            size:     @buffer.size,
            max_size: @max_size,
            feature:  :klog
          }
        end
      end
    end
  end
end