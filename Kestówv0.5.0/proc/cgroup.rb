# frozen_string_literal: true

# Kestówv 0.5.0 - proc/cgroup.rb
#
# Control group simulation.
# Registers cgroup features.

module Kestowv
  module Proc
    module Cgroup
      @cgroups = {}
      @mutex   = Mutex.new

      class << self
        def register_features
          Boot.register(:proc_cgroup)
          Boot.set_bit(:proc_cgroup)
        end

        def create(name)
          @mutex.synchronize { @cgroups[name] = {} }
        end

        def to_a
          @cgroups.keys
        end

        def stats
          {
            feature: :proc_cgroup,
            cgroups: @cgroups.size
          }
        end
      end
    end
  end
end