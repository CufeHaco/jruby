# frozen_string_literal: true

# Kestówv 0.5.0 - hal/cpu.rb
#
# CPU abstraction layer.
# Registers CPU features in the bit vector.

module Kestowv
  module Hal
    module Cpu
      @cores    = 1
      @features = []

      class << self
        def register_features
          Boot.register(:hal_cpu)
          Boot.set_bit(:hal_cpu)
        end

        def detect
          @cores = Etc.nprocessors rescue 1
          @features << :smp if @cores > 1
        end

        def cores
          @cores
        end

        def features
          @features
        end

        def to_a
          {
            cores:    @cores,
            features: @features
          }
        end

        def stats
          {
            feature: :hal_cpu,
            cores:   @cores
          }
        end
      end
    end
  end
end