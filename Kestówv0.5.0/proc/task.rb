# frozen_string_literal: true

# Kestówv 0.5.0 — proc/task.rb
#
# Task (lightweight process / thread group entry).
# Integrates with KThread, mm::VmSpace, and KObject lifecycle.

module Kestowv
  module Proc
    class Task < Kestowv::Core::KObject

      attr_reader :tid, :name

      # Task states — mirrors Linux task_struct states.
      STATES = %i[ready running blocked zombie].freeze

      # Class-level TID allocator — promoted from @@ to class ivar
      # so it doesn't leak across subclasses via Ruby's @@ inheritance.
      @next_tid  = 0
      @tid_mutex = Mutex.new

      def self.next_tid
        @tid_mutex.synchronize { @next_tid += 1 }
      end

      # --------------------------------------------------------
      # LIFECYCLE
      # --------------------------------------------------------

      def initialize(name: nil, vm_space: nil)
        super(type_tag: :task)

        @tid      = self.class.next_tid
        @name     = (name || :"task_#{@tid}").to_sym
        @state    = :ready
        @vm_space = vm_space
        @cred     = nil
        @limits   = nil
        @ns_set   = nil

        Boot.register(task_bit)
        Boot.set_bit(task_bit)
      end

      # --------------------------------------------------------
      # STATE MANAGEMENT — through inherited @mutex
      # --------------------------------------------------------

      def state
        @mutex.synchronize { @state }
      end

      def state=(new_state)
        raise ArgumentError, "Invalid state: #{new_state}" unless STATES.include?(new_state)

        @mutex.synchronize { @state = new_state }

        # Reflect terminal state in bit vector
        Boot.clear_bit(task_bit) if new_state == :zombie
      end

      def transition(new_state)
        self.state = new_state
        self
      end

      def runnable?
        @mutex.synchronize { @state == :ready || @state == :running }
      end

      def blocked?
        @mutex.synchronize { @state == :blocked }
      end

      def zombie?
        @mutex.synchronize { @state == :zombie }
      end

      # --------------------------------------------------------
      # VM SPACE
      # --------------------------------------------------------

      def vm_space
        @mutex.synchronize { @vm_space }
      end

      def assign_vm_space(space)
        raise ArgumentError, "Expected VmSpace" unless space.is_a?(Mm::VmSpace)
        @mutex.synchronize { @vm_space = space }
        self
      end

      # --------------------------------------------------------
      # CREDENTIALS
      # --------------------------------------------------------

      def cred
        @mutex.synchronize { @cred }
      end

      def assign_credentials(cred)
        raise ArgumentError, "Expected Cred" unless cred.is_a?(Proc::Credentials::Cred)
        @mutex.synchronize { @cred = cred }
        self
      end

      # --------------------------------------------------------
      # LIMITS
      # --------------------------------------------------------

      def limits
        @mutex.synchronize { @limits }
      end

      def assign_limits(limits)
        @mutex.synchronize { @limits = limits }
        self
      end

      # --------------------------------------------------------
      # NAMESPACE SET
      # --------------------------------------------------------

      def ns_set
        @mutex.synchronize { @ns_set }
      end

      def assign_ns_set(ns_set)
        raise ArgumentError, "Expected NamespaceSet" unless ns_set.is_a?(Proc::Namespace::NamespaceSet)
        @mutex.synchronize { @ns_set = ns_set }
        self
      end

      # --------------------------------------------------------
      # LIFECYCLE OVERRIDE
      # --------------------------------------------------------

      def destroy
        @mutex.synchronize { @state = :zombie }
        Boot.clear_bit(task_bit)
        super
      end

      # --------------------------------------------------------
      # INTROSPECTION
      # --------------------------------------------------------

      def to_h
        @mutex.synchronize do
          super.merge(
            tid:      @tid,
            name:     @name,
            state:    @state,
            vm_space: @vm_space&.to_s,
            cred:     @cred&.to_s,
            ns_set:   @ns_set&.to_h
          )
        end
      end

      def to_s
        "#<Task #{@name}[#{@tid}] state=#{state} rc=#{refcount}>"
      end

      private

      def task_bit
        :"proc_task_#{@tid}"
      end
    end
  end
end

# --------------------------------------------------------
# AUTO-REGISTER
# Remove :core_scheduler until that module exists.
# --------------------------------------------------------
Kestowv::Config::Modules.register(
  :proc_task,
  __FILE__,
  feature:    :proc_task,
  depends_on: [:core_kobject, :core_thread, :mm_vm_space]
)
