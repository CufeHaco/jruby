# frozen_string_literal: true

# Kestówv 0.5.0 — init.rb
#
# Kernel initialization and boot sequence.
# Wires all major subsystems together and spawns PID 1 (init task).
#
# Boot order matters — each step depends on the previous.

module Kestowv
  module Init

    # The fully wired init task — accessible after boot.
    @init_task = nil
    @booted    = false
    @mutex     = Mutex.new

    class << self

      # --------------------------------------------------------
      # BOOT REGISTRATION
      # --------------------------------------------------------

      def register_with_boot
        Boot.register(:init)
        Boot.set_bit(:init)
        self
      end

      # --------------------------------------------------------
      # MAIN BOOT SEQUENCE
      # --------------------------------------------------------

      def boot
        @mutex.synchronize do
          raise "Already booted — call reset! first" if @booted
        end

        log "Starting Kestówv #{Boot::VERSION} boot sequence"

        # Step 1 — HAL
        step("HAL: CPU") do
          Hal::Cpu.register_with_boot
        end

        step("HAL: Memory") do
          Hal::Memory.register_with_boot
        end

        # Step 2 — Memory Management
        # 1024 frames × 4KB = 4MB early boot allocation
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
          # Future: Scheduler.run(task)
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

      # --------------------------------------------------------
      # STATS
      # --------------------------------------------------------

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

      private

      # --------------------------------------------------------
      # PID 1 — INIT TASK
      # --------------------------------------------------------

      def create_init_task
        # 1. Address space
        vm_space = Mm::MemoryManager.create_vm_space(name: :init)

        # 2. Root namespace set — all 7 types, all root namespaces
        #    create_set with no unshare: gives root namespaces for every type
        ns_set = Proc::Namespace.create_set(unshare: [])

        # 3. Root credentials — full capability set
        cred = Proc::Credentials.root

        # 4. Default resource limits
        limits = Proc::Limits.default

        # 5. Construct the Task
        task = Proc::Task.new(name: :init)
        task.assign_vm_space(vm_space)
        task.assign_credentials(cred)
        task.assign_limits(limits)
        task.assign_ns_set(ns_set)

        # 6. Allocate PID — reserved PIDs start at 2, so we force PID 1
        #    by pre-registering it in the Pid module before allocate runs.
        #    Pid::RESERVED covers 0 and 1; bind task to PID 1 directly.
        Proc::Pid.bind(1, task)
        Proc::Pid.instance_variable_get(:@pid_map)[1] = {
          state: :allocated, task: task
        }

        # 7. Session — SID 1, init is the session leader
        Proc::Session.create_session(1)

        # 8. Root cgroup assignment
        root_cg = Proc::Cgroup.root
        Proc::Cgroup.assign(1, root_cg.id) if root_cg

        # 9. Boot filesystem visible in init's namespace
        Fs.mount("/proc", Fs.tmpfs(name: "procfs"), ns_id: ns_set.ns_id(:mount))

        task
      end

      # --------------------------------------------------------
      # LOGGING
      # --------------------------------------------------------

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

# --------------------------------------------------------
# AUTO-REGISTER — but do NOT auto-boot.
# Call Kestowv::Init.boot explicitly.
# --------------------------------------------------------
Kestowv::Init.register_with_boot
