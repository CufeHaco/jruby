# frozen_string_literal: true

# Kestówv 0.5.0 - core/kobject.rb
#
# Basic kobject (kernel object) system.
# Registers kobject features.

module Kestowv
  module Core
    module Kobject
      @objects = {}
      @next_id = 1
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:core_kobject)
          Boot.set_bit(:core_kobject)
        end

        def create(type)
          @mutex.synchronize do
            id = @next_id
            @next_id += 1
            @objects[id] = { type: type, created_at: Time.now }
            id
          end
        end

        def get(id)
          @objects[id]
        end

        def remove(id)
          @mutex.synchronize { @objects.delete(id) }
        end

        def to_a
          @objects
        end

        def stats
          {
            feature: :core_kobject,
            count:   @objects.size
          }
        end
      end
    end
  end
end