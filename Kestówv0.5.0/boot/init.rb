# frozen_string_literal: true

# Kestówv 0.5.0 - init.rb
#
# Modernized to use the new unified Boot system:
# - Boot.load / Boot.load_directory
# - auto_version + ByteClass filtering
# - Boot::Config + error handling
# - Bit vector feature flags for boot phases
#
# Includes full PID 1 (init task) creation with VmSpace, Credentials,
# NamespaceSet, Limits, Session, Cgroup, and signal state wiring.

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

    # The fully wired init task — accessible after boot.
    @init_task = nil
    @booted    = false
    @mutex     = Mutex.new

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
      # BOOT
      # ============================================================

      def boot
        @mutex.synchronize do
          raise "Already booted — call reset! first" if @booted
        end

        log "Starting Kestówv #{Boot::VERSION} boot sequence"

        register_features
        Boot.set_bit(:early_boot)

        # Configure Boot
        Boot.config.auto_version = true
        Boot.config.quiet        = false
        Boot.config.on_error     = :warn

        # Step 1 — HAL
        step("HAL: CPU") do
          Hal::Cpu.register_with_boot
        end

        step("HAL: Memory") do
          Hal::Memory.register_with_boot
        end

        # Step 2 — Memory Management
        step("MM: MemoryManager") do
          Mm::MemoryManager.init(1024)
        end

        # Step 3 — Filesystem (tmpfs root + optional hostfs)
        step("FS: init") do
          Fs.init(ns_id: nil, mount_host: true)
        end

        # Step 4 — IPC
        step("IPC: register") do
          Ipc.register_with_boot
        end

        # Step 5 — Process layer
        step("Proc: Pid") do
          Proc::Pid.register_with_boot
        end

        step("Proc: Cgroup") do
          Proc::Cgroup.register_with_boot
        end

        step("Proc: Namespace") do
          Proc::Namespace.register_with_boot
        end

        step("Proc: Session") do
          Proc::Session.register_with_boot
        end

        step("Proc: Credentials") do
          Proc::Credentials.register_with_boot
        end

        step("Proc: Limits") do
          Proc::Limits.register_with_boot
        end

        # Step 6 — Spawn PID 1
        task = nil
        step("Init: PID 1") do
          task = create_init_task
        end

        # Step 7 — Transition init to running
        step("Init: scheduler handoff") do
          task.transition(:running)
        end

        @mutex.synchronize do
          @init_task = task
          @booted    = true
        end

        Boot.set_bit(:kernel_booted)
        log "Boot complete — #{Proc::Pid.stats[:allocated]} PIDs active"

        task
      end

      def booted?
        @mutex.synchronize { @booted }
      end

      def init_task
        @mutex.synchronize { @init_task }
      end

      def reset!
        @mutex.synchronize do
          @init_task = nil
          @booted    = false
        end
        Boot.clear_bit(:kernel_booted)
        self
      end

      # ============================================================
      # PID 1 — INIT TASK (full wiring)
      # ============================================================

      def create_init_task
        # 1. Address space
        vm_space = Mm::MemoryManager.create_vm_space(name: :init)

        # 2. Root namespace set — all 7 types
        ns_set = Proc::Namespace.create_set(unshare: [])

        # 3. Root credentials
        cred = Proc::Credentials.root

        # 4. Default resource limits
        limits = Proc::Limits.default

        # 5. Construct the Task
        task = Proc::Task.new(name: :init)
        task.assign_vm_space(vm_space)
        task.assign_credentials(cred)
        task.assign_limits(limits)
        task.assign_ns_set(ns_set)

        # 6. Allocate PID 1
        Proc::Pid.bind(1, task)
        Proc::Pid.instance_variable_get(:@pid_map)[1] = {
          state: :allocated, task: task
        }

        # 7. Session — SID 1
        Proc::Session.create_session(1)

        # 8. Root cgroup assignment
        root_cg = Proc::Cgroup.root
        Proc::Cgroup.assign(1, root_cg.id) if root_cg

        # 9. Boot filesystem visible in init's namespace
        Fs.mount("/proc", Fs.tmpfs(name: "procfs"), ns_id: ns_set.ns_id(:mount))

        task
      end

      # ============================================================
      # DIRECTORY LAYOUT (from previous boot/init.rb)
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

      def stats
        {
          feature:   :init,
          booted:    booted?,
          init_task: @init_task&.to_h,
          mm:        (Mm::MemoryManager.stats rescue {}),
          fs:        (Fs.stats rescue {}),
          proc_pid:  Proc::Pid.stats
        }
      end

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

      private

      def step(label, &block)
        block.call
        log "✓ #{label}"
      rescue => e
        warn "[Init] ✗ #{label} FAILED: #{e.message}"
        Boot.handle_error(e, { step: label })
        raise
      end

      def log(msg)
        return if Boot.config.quiet
        warn "[Init] #{msg}"
      end
    end
  end
end

# Standalone execution support
if __FILE__ == $0
  Kestowv::Init.boot
end
