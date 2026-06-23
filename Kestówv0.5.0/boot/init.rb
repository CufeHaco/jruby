# frozen_string_literal: true

# Kestówv 0.5.0 - init.rb
#
# Kestówv-specific bootloader.
# Uses Boot primitives + bit vector feature flags for tracking
# boot phases and subsystem state.

require_relative 'boot'

module Kestowv
  module Init
    # ============================================================
    # KESTÓWV DYNAMIC STATE ARRAYS
    # ============================================================

    $kestowv_root_dirs    ||= []
    $kestowv_root_files   ||= []
    $kestowv_user_dirs    ||= []
    $kestowv_user_files   ||= []
    $kestowv_system_dirs  ||= []
    $kestowv_system_files ||= []

    class << self
      # ============================================================
      # FEATURE FLAG REGISTRATION (Bit Vector)
      # ============================================================

      def register_features
        [
          :early_boot,
          :directory_layout,
          :core_subsystems,
          :hal,
          :memory_management,
          :process_management,
          :filesystem,
          :networking,
          :ipc,
          :kestowv_init_complete
        ].each { |f| Boot.register(f) }
      end

      # ============================================================
      # DIRECTORY LAYOUT
      # ============================================================

      def setup_directories
        puts "→ Setting up Kestówv runtime directory layout..."

        create_root_structure
        create_system_structure
        create_user_structure

        Boot.set_bit(:directory_layout)
        puts "  ✓ Directory layout initialized"
      end

      def create_root_structure
        %w[bin sbin lib etc var tmp dev proc sys home root kestowv usr].each do |d|
          $kestowv_root_dirs << "/#{d}"
        end

        $kestowv_root_files += %w[
          /etc/kestowv/kestowv.conf
          /var/log/kestowv.log
        ]
      end

      def create_system_structure
        %w[
          /kestowv /kestowv/bin /kestowv/lib /kestowv/boot
          /kestowv/config /kestowv/modules /kestowv/var
          /kestowv/var/log /kestowv/var/run
        ].each { |d| $kestowv_system_dirs << d }

        $kestowv_system_files += %w[
          /kestowv/boot/boot.rb
          /kestowv/config/params.conf
        ]
      end

      def create_user_structure
        $kestowv_user_dirs  += %w[/home /home/user]
        $kestowv_user_files += %w[/home/user/.kestowvrc]
      end

      # ============================================================
      # MAIN BOOT SEQUENCE
      # ============================================================

      def boot
        puts "\n=== Kestówv 0.5.0 Init ==="

        register_features
        Boot.set_bit(:early_boot)

        # Phase 1: Early boot
        Boot.load_files(%w[
          kernel/boot/early_console.rb
          kernel/boot/early_memory.rb
          kernel/boot/panic.rb
        ])

        setup_directories

        # Phase 2: Core subsystems
        puts "→ Booting core subsystems..."
        Boot.set_bit(:core_subsystems)

        # Phase 3: HAL + Memory + Process
        puts "→ Initializing HAL, MM, and Process layers..."
        Boot.set_bit(:hal)
        Boot.set_bit(:memory_management)
        Boot.set_bit(:process_management)

        # Phase 4: Filesystem, Networking, IPC
        puts "→ Bringing up FS, Net, and IPC..."
        Boot.set_bit(:filesystem)
        Boot.set_bit(:networking)
        Boot.set_bit(:ipc)

        Boot.set_bit(:kestowv_init_complete)

        puts "\n✓ Kestówv init complete"
        puts "  Features enabled: #{enabled_features.join(', ')}"
      end

      # ============================================================
      # FEATURE FLAG HELPERS
      # ============================================================

      def enabled_features
        Boot.enabled_features
      end

      def feature_enabled?(name)
        Boot.bit_set?(name)
      end

      # ============================================================
      # INTROSPECTION
      # ============================================================

      def to_a
        {
          root_dirs:    $kestowv_root_dirs,
          root_files:   $kestowv_root_files,
          system_dirs:  $kestowv_system_dirs,
          system_files: $kestowv_system_files,
          user_dirs:    $kestowv_user_dirs,
          user_files:   $kestowv_user_files
        }
      end

      def stats
        {
          total_directories: $kestowv_root_dirs.size +
                             $kestowv_system_dirs.size +
                             $kestowv_user_dirs.size,
          features_enabled: enabled_features.size,
          init_complete:    feature_enabled?(:kestowv_init_complete)
        }
      end
    end
  end
end

# Standalone execution support
if __FILE__ == $0
  Kestowv::Init.boot
end
