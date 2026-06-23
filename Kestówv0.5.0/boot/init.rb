# frozen_string_literal: true

# Kestówv 0.5.0 - init.rb
#
# Modernized to use the new unified Boot system:
# - Boot.load / Boot.load_directory
# - auto_version + ByteClass filtering
# - Boot::Config + error handling
# - Bit vector feature flags for boot phases

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
      # FEATURE FLAG REGISTRATION
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
        puts "Setting up Kestówv runtime directory layout..."

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
      # MAIN BOOT SEQUENCE (using new Boot logic)
      # ============================================================

      def boot
        puts "\n=== Kestówv 0.5.0 Init ==="

        register_features
        Boot.set_bit(:early_boot)

        # Configure Boot
        Boot.config.auto_version = true
        Boot.config.quiet        = false
        Boot.config.on_error     = :warn

        # Phase 1: Early boot (explicit files)
        puts "Phase 1: Early boot..."
        Boot.load([
          "kernel/boot/early_console.rb",
          "kernel/boot/early_memory.rb",
          "kernel/boot/panic.rb"
        ], auto_version: true)

        setup_directories

        # Phase 2: Core subsystems (smart directory load)
        puts "Phase 2: Booting core subsystems..."
        Boot.set_bit(:core_subsystems)

        Boot.load_directory("core", recursive: true, auto_version: true) do |path|
          case Boot.byte_dispatch(path)
          in { kind: :syscall | :kernel_module, confidence: (0.85..) } then true
          in { kind: :deprecated } then false
          else true
          end
        end

        # Phase 3: HAL + Memory + Process
        puts "Phase 3: Initializing HAL, MM, and Process layers..."
        Boot.set_bit(:hal)
        Boot.set_bit(:memory_management)
        Boot.set_bit(:process_management)

        Boot.load_directory("hal",  recursive: true, auto_version: true)
        Boot.load_directory("mm",   recursive: true, auto_version: true)
        Boot.load_directory("proc", recursive: true, auto_version: true)

        # Phase 4: Filesystem, Networking, IPC
        puts "Phase 4: Bringing up FS, Net, and IPC..."
        Boot.set_bit(:filesystem)
        Boot.set_bit(:networking)
        Boot.set_bit(:ipc)

        Boot.load_directory("fs",  recursive: true, auto_version: true)
        Boot.load_directory("net", recursive: true, auto_version: true)
        Boot.load_directory("ipc", recursive: true, auto_version: true)

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
