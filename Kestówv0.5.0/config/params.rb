# frozen_string_literal: true

# Kestówv 0.5.0 - config/params.rb
#
# Sysctl-style kernel parameters.
# Parameters are registered as bit vector features for fast enabled/disabled checks.
# All loading goes through Boot primitives.

module Kestowv
  module Config
    module Params
      @params = {}
      @mutex  = Mutex.new

      class << self
        def register(name, default: nil, description: nil)
          @mutex.synchronize do
            key = name.to_sym
            @params[key] = {
              value:       default,
              default:     default,
              description: description
            }
            Boot.register(key)
          end
        end

        def set(name, value)
          key = name.to_sym
          return false unless @params.key?(key)

          @params[key][:value] = value
          Boot.set_bit(key) if value
          Boot.clear_bit(key) unless value
          true
        end

        def get(name)
          key = name.to_sym
          @params.dig(key, :value)
        end

        def enabled?(name)
          Boot.bit_set?(name)
        end

        def reset(name)
          key = name.to_sym
          return false unless @params.key?(key)

          @params[key][:value] = @params[key][:default]
          Boot.clear_bit(key)
          true
        end

        def all
          @params.keys
        end

        def to_a
          @params.map do |name, info|
            {
              name:        name,
              value:       info[:value],
              default:     info[:default],
              description: info[:description],
              enabled:     Boot.bit_set?(name)
            }
          end
        end

        def stats
          {
            total:   @params.size,
            enabled: @params.count { |name, _| Boot.bit_set?(name) }
          }
        end
      end
    end
  end
end