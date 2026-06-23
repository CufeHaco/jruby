# frozen_string_literal: true

# Kestówv 0.5.0 - config/defaults.rb
#
# Default configuration values.
# Registers sensible defaults as bit vector features.

module Kestowv
  module Config
    module Defaults
      DEFAULTS = {
        scheduler:       :fair,
        gc_mode:         :balanced,
        network_buffers: :normal,
        log_level:       :info,
        hot_reload:      false,
        max_threads:     8
      }.freeze

      class << self
        def apply
          DEFAULTS.each do |key, _|
            Boot.register(:"default_#{key}")
            Boot.set_bit(:"default_#{key}")
          end
        end

        def get(key)
          DEFAULTS[key.to_sym]
        end

        def to_a
          DEFAULTS.map { |k, v| { key: k, value: v, feature: :"default_#{k}" } }
        end
      end
    end
  end
end