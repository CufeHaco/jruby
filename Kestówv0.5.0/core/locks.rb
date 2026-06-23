# frozen_string_literal: true

# Kestówv 0.5.0 - core/locks.rb
#
# Basic locking primitives.
# Registers lock types as features.

module Kestowv
  module Core
    module Locks
      @locks = {}
      @mutex = Mutex.new

      class << self
        def register_type(name)
          Boot.register(:"lock_#{name}")
          Boot.set_bit(:"lock_#{name}")
        end

        def create(name, type: :mutex)
          register_type(type)
          @mutex.synchronize do
            @locks[name] = { type: type, mutex: Mutex.new }
          end
        end

        def synchronize(name)
          lock = @locks[name]
          return yield unless lock
          lock[:mutex].synchronize { yield }
        end

        def to_a
          @locks.keys
        end
      end
    end
  end
end