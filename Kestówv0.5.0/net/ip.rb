# frozen_string_literal: true

# Kestówv 0.5.0 - net/ip.rb
#
# IP layer simulation.
# Registers IP features.

module Kestowv
  module Net
    module Ip
      @routes = []
      @mutex = Mutex.new

      class << self
        def register_features
          Boot.register(:net_ip)
          Boot.set_bit(:net_ip)
        end

        def add_route(destination, gateway)
          @mutex.synchronize do
            @routes << { destination: destination, gateway: gateway }
          end
        end

        def to_a
          @routes
        end

        def stats
          {
            feature: :net_ip,
            routes: @routes.size
          }
        end
      end
    end
  end
end