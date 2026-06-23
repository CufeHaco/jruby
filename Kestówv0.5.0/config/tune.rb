# frozen_string_literal: true

# Kestówv 0.5.0 - config/tune.rb
#
# Performance tuning profiles.
# Profiles register themselves as bit vector features.
# All loading uses Boot primitives.

module Kestowv
  module Config
    module Tune
      PROFILES = {
        default: {
          vm:     { gc: :balanced },
          net:    { buffers: :normal },
          kernel: { scheduler: :fair }
        },
        performance: {
          vm:     { gc: :aggressive },
          net:    { buffers: :large },
          kernel: { scheduler: :realtime }
        },
        powersave: {
          vm:     { gc: :conservative },
          net:    { buffers: :small },
          kernel: { scheduler: :powersave }
        }
      }.freeze

      @current_profile = :default

      class << self
        def register_profiles
          PROFILES.keys.each { |p| Boot.register(:"profile_#{p}") }
        end

        def apply(profile)
          key = profile.to_sym
          return false unless PROFILES.key?(key)

          @current_profile = key
          Boot.set_bit(:"profile_#{key}")

          (PROFILES.keys - [key]).each { |other| Boot.clear_bit(:"profile_#{other}") }

          true
        end

        def current
          @current_profile
        end

        def settings
          PROFILES[@current_profile]
        end

        def to_a
          {
            current:   @current_profile,
            available: PROFILES.keys,
            settings:  settings
          }
        end
      end
    end
  end
end