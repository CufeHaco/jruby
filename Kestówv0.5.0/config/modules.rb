# frozen_string_literal: true

# Kestówv 0.5.0 - config/modules.rb
#
# Module discovery and loading system.
# Uses Boot primitives exclusively (no static require/load).
# Registers features in the bit vector and supports hot reloading.

module Kestowv
  module Config
    module Modules
      # ============================================================
      # MODULE REGISTRY (bit vector backed)
      # ============================================================

      @registered_modules = {}
      @mutex = Mutex.new

      class << self
        def register(name, path, feature: nil)
          @mutex.synchronize do
            key = name.to_sym
            @registered_modules[key] = {
              path: path,
              feature: feature || key,
              loaded: false
            }
            Boot.register(feature || key)
          end
        end

        def registered
          @registered_modules.keys
        end

        def loaded?(name)
          key = name.to_sym
          mod = @registered_modules[key]
          return false unless mod
          Boot.bit_set?(mod[:feature])
        end

        # ============================================================
        # LOADING (always through Boot)
        # ============================================================

        def load_module(name)
          key = name.to_sym
          entry = @registered_modules[key]
          return false unless entry

          path    = entry[:path]
          feature = entry[:feature]

          success = Boot.load(path)

          if success
            entry[:loaded] = true
            # Boot.load marks the basename symbol; we also mark the feature
            # alias explicitly so aliased features (e.g. :hal_cpu for cpu.rb)
            # are correctly tracked in the bit vector.
            Boot.set_bit(feature)
          end

          success
        end

        def load_all
          @registered_modules.keys.map { |name| [name, load_module(name)] }
        end

        def hotload_module(name)
          key = name.to_sym
          entry = @registered_modules[key]
          return false unless entry

          path    = entry[:path]
          feature = entry[:feature]

          Boot.invalidate(feature)
          success = Boot.hotload(path)

          if success
            entry[:loaded] = true
            # Same aliased-feature rationale as load_module above
            Boot.set_bit(feature)
          end

          success
        end

        # ============================================================
        # DISCOVERY (can be extended later with ByteMatcher + .map)
        # ============================================================

        def scan_and_register(base_path = 'Kestówv0.5.0')
          puts "→ Scanning modules under #{base_path} (manual registration for now)"

          register(:core_klog,      "#{base_path}/core/klog.rb",      feature: :klog)
          register(:core_scheduler, "#{base_path}/core/scheduler.rb", feature: :scheduler)
          register(:hal_cpu,        "#{base_path}/hal/cpu.rb",        feature: :hal_cpu)
          register(:mm_virtual,     "#{base_path}/mm/virtual.rb",       feature: :mm_virtual)
          register(:proc_task,      "#{base_path}/proc/task.rb",        feature: :proc_task)
        end

        # ============================================================
        # INTROSPECTION
        # ============================================================

        def to_a
          @registered_modules.map do |name, info| do
            {
              name:    name,
              path:    info[:path],
              feature: info[:feature],
              loaded:  Boot.bit_set?(info[:feature])
            }
          end
        end

        def stats
          {
            total_registered: @registered_modules.size,
            loaded_count:     @registered_modules.count { |_, info| Boot.bit_set?(info[:feature]) }
          }
        end
      end
    end
  end
end