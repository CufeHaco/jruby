# frozen_string_literal: true

# Kestówv 0.5.0 — proc/credentials.rb
#
# Process credentials: UID/GID sets and capability bitmask.
# Mirrors Linux's cred struct — real/effective/saved IDs + capability sets.
# Credentials are immutable once created; use derive to produce new ones.

module Kestowv
  module Proc
    module Credentials

      # --------------------------------------------------------
      # CAPABILITIES — subset of Linux capability constants
      # --------------------------------------------------------

      module Cap
        CHOWN        = 0   # make arbitrary changes to file UIDs/GIDs
        DAC_OVERRIDE = 1   # bypass file read/write/exec permission checks
        KILL         = 5   # send signals to any process
        SETUID       = 7   # make arbitrary changes to process UIDs
        SETGID       = 8   # make arbitrary changes to process GIDs
        NET_ADMIN    = 12  # perform network administration tasks
        SYS_ADMIN    = 21  # range of system administration operations
        SYS_PTRACE   = 19  # trace arbitrary processes

        ALL = [CHOWN, DAC_OVERRIDE, KILL, SETUID, SETGID,
               NET_ADMIN, SYS_ADMIN, SYS_PTRACE].freeze

        def self.name_for(cap)
          constants.find { |c| const_get(c) == cap && c != :ALL }
        end
      end

      # --------------------------------------------------------
      # CRED — immutable credential set
      # --------------------------------------------------------

      Cred = Struct.new(
        :uid, :euid, :suid,    # real / effective / saved user IDs
        :gid, :egid, :sgid,    # real / effective / saved group IDs
        :groups,               # supplementary group list
        :caps_permitted,       # capability bitmask — what the process may use
        :caps_effective,       # capability bitmask — what the process is using
        keyword_init: true
      ) do
        def root?
          euid == 0
        end

        def member?(gid)
          self.gid == gid || egid == gid || groups.include?(gid)
        end

        def capable?(cap)
          caps_effective & (1 << cap) != 0
        end

        def permitted?(cap)
          caps_permitted & (1 << cap) != 0
        end

        # Raise a capability from permitted to effective.
        # Returns a new Cred — originals are immutable.
        def raise_cap(cap)
          return self unless permitted?(cap)
          derive(caps_effective: caps_effective | (1 << cap))
        end

        # Drop a capability from effective set.
        def drop_cap(cap)
          derive(caps_effective: caps_effective & ~(1 << cap))
        end

        # Produce a new Cred with overridden fields.
        def derive(**overrides)
          Cred.new(**to_h.merge(overrides))
        end

        def to_s
          "Cred(uid=#{uid}/#{euid} gid=#{gid}/#{egid} caps=#{caps_string})"
        end

        private

        def caps_string
          Cap::ALL.select { |c| capable?(c) }
                  .map   { |c| Cap.name_for(c)&.to_s&.downcase || c.to_s }
                  .join(",")
                  .then  { |s| s.empty? ? "none" : s }
        end
      end

      # --------------------------------------------------------
      # MODULE INTERFACE
      # --------------------------------------------------------

      @cred_count = 0
      @mutex      = Mutex.new

      class << self

        def register_with_boot
          Boot.register(:proc_credentials)
          Boot.set_bit(:proc_credentials)
          self
        end

        # Create a new immutable Cred.
        # Defaults to root with no capabilities.
        def create(uid: 0, gid: 0, groups: [], caps: [])
          cap_mask = caps.reduce(0) { |m, c| m | (1 << c) }

          cred = Cred.new(
            uid:            uid,
            euid:           uid,
            suid:           uid,
            gid:            gid,
            egid:           gid,
            sgid:           gid,
            groups:         groups.dup.freeze,
            caps_permitted: cap_mask,
            caps_effective: cap_mask
          )

          @mutex.synchronize { @cred_count += 1 }
          cred
        end

        # Root credential with all capabilities.
        def root
          create(uid: 0, gid: 0, caps: Cap::ALL)
        end

        # Unprivileged user credential — no capabilities.
        def user(uid:, gid:, groups: [])
          create(uid: uid, gid: gid, groups: groups, caps: [])
        end

        # Check if a cred passes a permission check for a given
        # protection flag set (integrates with mm::Protection).
        def permitted_access?(cred, flags)
          return true if cred.root?
          return true if cred.capable?(Cap::DAC_OVERRIDE)

          prot = Mm::Protection
          return false if prot.executable?(flags) && !cred.capable?(Cap::SYS_ADMIN)
          true
        end

        def stats
          @mutex.synchronize do
            {
              feature:     :proc_credentials,
              creds_issued: @cred_count
            }
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
  :proc_credentials,
  __FILE__,
  feature:    :proc_credentials,
  depends_on: [:proc_task, :mm_protection]
)
