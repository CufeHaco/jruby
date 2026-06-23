# frozen_string_literal: true

# Kestówv 0.5.0 - proc/namespace.rb
#
# Process namespace management.
# Registers namespace features.

module Kestowv
  module Proc
    module Namespace
      @namespaces = {}
      @mutex      = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_namespace)
          Boot.set_bit(:proc_namespace)
        end

        def create(name, type)
          @mutex.synchronize do
            @namespaces[name] = { type: type, created_at: Time.now }
          end
        end

        def get(name)
          @namespaces[name]
        end

        def list
          @namespaces.keys
        end

        def to_a
          @namespaces
        end

        def stats
          {
            feature: :proc_namespace,
            count:   @namespaces.size
          }
        end
      end
    end
  end
end