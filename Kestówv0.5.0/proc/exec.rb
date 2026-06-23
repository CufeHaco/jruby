# frozen_string_literal: true

# Kestówv 0.5.0 — proc/exec.rb
#
# Program execution (exec family).
# Manages the exec lifecycle: path validation, VmSpace setup,
# and task address space replacement.
# Binary loading is stubbed — fills in when fs/ and loader/ lands.

module Kestowv
  module Proc
    module Exec

      # Exec attempt record — kept for audit / debug.
      Record = Struct.new(:path, :argv, :envp, :pid, :result, :at, keyword_init: true)

      @history = []
      @mutex   = Mutex.new

      HISTORY_CAP = 64

      class << self

        # --------------------------------------------------------
        # BOOT REGISTRATION
        # --------------------------------------------------------

        def register_with_boot
          Boot.register(:proc_exec)
          Boot.set_bit(:proc_exec)
          self
        end

        # --------------------------------------------------------
        # EXEC FAMILY
        # --------------------------------------------------------

        # execve — replace current task's address space with a new program.
        #
        # task:    the Task to replace (defaults to caller's implied task)
        # path:    executable path
        # argv:    argument vector
        # envp:    environment vector
        #
        # Returns :ok on success, or an error symbol.
        def execve(path, argv = [], envp = [], task: nil)
          result = run_exec(path, argv, envp, task: task)
          record(path, argv, envp, task&.tid, result)
          result
        end

        # execv — execve with inherited environment.
        def execv(path, argv = [], task: nil)
          execve(path, argv, inherited_env, task: task)
        end

        # execl — varargs form (pass args as splat).
        def execl(path, *argv, task: nil)
          execve(path, argv, inherited_env, task: task)
        end

        # --------------------------------------------------------
        # INTROSPECTION
        # --------------------------------------------------------

        def history
          @mutex.synchronize { @history.dup }
        end

        def stats
          @mutex.synchronize do
            by_result = @history.group_by(&:result)
                                .transform_values(&:size)
            {
              feature:    :proc_exec,
              attempts:   @history.size,
              by_result:  by_result
            }
          end
        end

        private

        # --------------------------------------------------------
        # EXEC IMPLEMENTATION
        # --------------------------------------------------------

        def run_exec(path, argv, envp, task:)
          # Step 1: validate path
          unless valid_path?(path)
            warn "[Exec] Invalid path: #{path.inspect}" unless Boot.config.quiet
            return :enoent
          end

          # Step 2: check execute permission via byte_dispatch
          bc = Boot.byte_dispatch(path)
          if bc.skip?
            warn "[Exec] Non-executable file: #{path} (#{bc})" unless Boot.config.quiet
            return :eacces
          end

          # Step 3: create new VmSpace for the program
          vm_space = Mm::MemoryManager.create_vm_space(name: :"exec_#{File.basename(path)}")

          # Step 4: assign to task
          task&.assign_vm_space(vm_space)

          # Step 5: load binary into VmSpace
          # TODO: implement ELF/MachO loader when fs/ lands
          # loader_result = Loader.load(path, vm_space, argv: argv, envp: envp)
          warn "[Exec] Binary loading not yet implemented — #{path}" unless Boot.config.quiet

          # Step 6: transition task to :running
          task&.transition(:running)

          :ok
        rescue => e
          Boot.handle_error(e, { path: path, argv: argv })
          :efault
        end

        def valid_path?(path)
          return false unless path.is_a?(String) && !path.empty?
          # Real check deferred until fs/ lands
          # For now: must look like an absolute or relative path
          path =~ /\A[\/\w\.\-]+\z/ ? true : false
        end

        def inherited_env
          ENV.to_h rescue {}
        end

        def record(path, argv, envp, pid, result)
          entry = Record.new(
            path:   path,
            argv:   argv,
            envp:   envp.keys rescue [],
            pid:    pid,
            result: result,
            at:     Time.now.freeze
          )

          @mutex.synchronize do
            @history << entry
            @history.shift if @history.size > HISTORY_CAP
          end
        end
      end
    end
  end
end

# --------------------------------------------------------
# AUTO-REGISTER
# --------------------------------------------------------
Kestowv::Config::Modules.register(
  :proc_exec,
  __FILE__,
  feature:    :proc_exec,
  depends_on: [:proc_task, :proc_pid, :mm_vm_space]
)
