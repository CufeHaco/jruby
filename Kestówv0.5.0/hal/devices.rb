# frozen_string_literal: true

# Kestówv 0.5.0 - hal/devices.rb
#
# Device management abstraction.
# Registers device features.

module Kestowv
  module Hal
    module Devices
      @devices = {}
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:hal_devices)
          Boot.set_bit(:hal_devices)
        end

        def register(name, type)
          @mutex.synchronize do
            @devices[name] = { type: type, state: :registered }
          end
        end

        def list
          @devices.keys
        end

        def get(name)
          @devices[name]
        end

        def to_a
          @devices
        end

        def stats
          {
            feature: :hal_devices,
            count:   @devices.size
          }
        end
      end
    end
  end
end