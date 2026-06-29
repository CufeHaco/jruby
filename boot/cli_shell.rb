# frozen_string_literal: true

# Kestówv 0.5.1 — boot/cli_shell.rb
#
# Kernel-controlled CRuby userspace shell.
#
# Architecture:
#   JRuby (Kestowv kernel)
#     ├── Proc::Exec        — records the CRuby shell exec in the kernel task table
#     ├── Proc::Pid         — allocates a real PID for the shell (visible to `ps`)
#     ├── Net::UnixHub      — tracks the UDS connection in the kernel socket registry
#     └── CommandDispatcher — answers {"cmd"=>.., "args"=>[..]} requests from the shell
#
#   CRuby (cli/shell.rb)
#     └── interactive REPL — sends commands, prints responses
#
# Unlike tk_stress.rb/tui_stress.rb, the CRuby side is NOT spawned in its own
# terminal window — it inherits this process's stdin/stdout/stderr, so the
# shell appears directly in the same terminal that launched the kernel.
#
# Run: jruby boot/cli_shell.rb

require 'socket'
require 'msgpack'
require_relative 'init'

Boot.config.quiet = true
Kestowv::Init.boot

include Kestowv
KProc   = Kestowv::Proc
Hub     = Net::UnixHub
USocket = Net::UnixSocket

SOCK_PATH  = "/tmp/kestowv_cli_#{Process.pid}.sock"
CLI_SCRIPT = File.expand_path("../RubyOS 0.1.0/pid1.rb", __dir__)

# Kestowv itself always runs on JRuby — but userspace (PID 1 / Rubian) runs
# on CRuby, so under JRuby we must locate a real CRuby binary rather than
# resolving RbConfig against the JVM process we're already running in.
RUBY_BIN =
  if defined?(JRUBY_VERSION)
    %w[/usr/local/bin/ruby /usr/bin/ruby].find { |p| File.executable?(p) } ||
      abort("No CRuby interpreter found for the userspace shell")
  else
    (RbConfig::CONFIG['bindir'] + '/' + RbConfig::CONFIG['ruby_install_name']) rescue '/usr/bin/ruby'
  end

# ── Register the CRuby shell with the kernel ──────────────────────────────────
cli_task = KProc::Task.new(name: :cli_shell)
cli_task.assign_credentials(KProc::Credentials.user(uid: 1000, gid: 1000))
cli_pid  = KProc::Pid.allocate(task: cli_task)
KProc::Exec.execve(CLI_SCRIPT, [RUBY_BIN, CLI_SCRIPT, SOCK_PATH], {}, task: cli_task)
cli_task.transition(:running)

# ── OS-level UDS server (kernel: registered with Net::UnixHub) ────────────────
File.delete(SOCK_PATH) if File.exist?(SOCK_PATH)
server   = UNIXServer.new(SOCK_PATH)
hub_sock = Net::UnixSocket::Socket.new(SOCK_PATH, :stream)
Hub.register(hub_sock)

# ── Spawn the CRuby shell — inherits this terminal's stdio directly ──────────
spawn_pid = Process.spawn(RUBY_BIN, CLI_SCRIPT, SOCK_PATH)
Process.detach(spawn_pid)

puts ""
puts "  [cli_shell] Kernel booted"
puts "  [cli_shell] Wave:   #{Core::Wave.stats[:threads]} daemon threads"
puts "  [cli_shell] Exec:   CRuby shell registered as pid=#{cli_pid} (tid=#{cli_task.tid})"
puts "  [cli_shell] UDS:    #{SOCK_PATH}"
puts "  [cli_shell] Spawned shell (OS pid=#{spawn_pid})"
puts "  [cli_shell] Waiting for CRuby shell to connect (up to 20s)..."

# ── Accept CRuby connection ───────────────────────────────────────────────────
client   = nil
deadline = Time.now + 20
loop do
  begin
    client = server.accept_nonblock
    break
  rescue IO::WaitReadable
    raise "CLI shell did not connect within 20s" if Time.now > deadline
    sleep 0.1
  end
end

puts "  [cli_shell] CRuby shell connected"
puts ""

# ── Command dispatcher — answers requests from the CRuby shell ───────────────
module CommandDispatcher
  COMMANDS = %w[help ps kill status uname ls cat write whoami sudo mounts exit quit].freeze

  class << self
    attr_accessor :cli_task

    def dispatch(req)
      cmd  = req["cmd"].to_s
      args = Array(req["args"])

      case cmd
      when "help"         then ok(help_text)
      when "ps"            then ok(ps_table)
      when "kill"          then kill(args)
      when "status"        then ok(status_info)
      when "uname"         then ok(uname_info)
      when "ls"            then ls(args)
      when "cat"           then cat(args)
      when "write"         then write(args)
      when "whoami"        then ok(whoami_info)
      when "sudo"          then sudo(args)
      when "mounts"        then ok(mounts_table)
      when "exit", "quit"  then ok({ "bye" => true })
      else                      err("unknown command: #{cmd.inspect}")
      end
    rescue => e
      err("#{e.class}: #{e.message}")
    end

    private

    def ok(data)  = { "ok" => true,  "data" => data }
    def err(msg)  = { "ok" => false, "error" => msg }

    def help_text
      "Commands: #{COMMANDS.join(', ')}"
    end

    def ps_table
      KProc::Pid.all_pids.map do |pid|
        task = KProc::Pid.task_for(pid)
        {
          "pid"   => pid,
          "tid"   => task&.tid,
          "name"  => task&.name.to_s,
          "state" => (task&.state || :unknown).to_s
        }
      end
    end

    def kill(args)
      pid   = args[0]&.to_i
      signo = args[1] ? args[1].to_i : Kestowv::Signal::SIGTERM
      return err("usage: kill <pid> [signal]") unless pid

      task = KProc::Pid.task_for(pid)
      return err("no such pid: #{pid}") unless task

      result = KProc::SignalDelivery.post(task, signo, sender_pid: 0, reason: :user)
      result == :ok ? ok({ "pid" => pid, "signal" => Kestowv::Signal.name(signo).to_s }) : err(result.to_s)
    end

    def status_info
      ws = Core::Wave.stats
      hs = Hub.stats
      ps = KProc::Pid.stats
      fs = Fs.stats

      {
        "booted" => Kestowv::Init.booted?,
        "wave"   => { "running"         => ws[:running],
                      "threads"         => ws[:threads],
                      "governor_factor" => ws[:governor_factor],
                      "cpu_cap"         => ws[:cpu_cap] },
        "hub"    => { "active_sockets" => hs[:active_sockets],
                      "backend"        => hs[:backend].to_s },
        "pid"    => { "allocated" => ps[:allocated],
                      "recycled"  => ps[:recycled],
                      "next_pid"  => ps[:next_pid] },
        "fs"     => { "initialized" => fs[:initialized],
                      "mounts"      => fs[:vfs][:mounts] }
      }
    end

    def uname_info
      {
        "kernel"  => "Kestowv",
        "version" => Boot::VERSION.to_s,
        "runtime" => RUBY_PLATFORM,
        "engine"  => (defined?(RUBY_ENGINE) ? RUBY_ENGINE : "unknown")
      }
    end

    def ls(args)
      path = args[0] || "/"
      res  = Fs::Vfs.resolve(path)
      return err("no such path: #{path}") unless res
      return err("backend does not support ls") unless res[:backend].respond_to?(:ls)

      entries = res[:backend].ls(res[:relative_path])
      entries ? ok(entries) : err("not a directory: #{path}")
    end

    def cat(args)
      path = args[0]
      return err("usage: cat <path>") unless path
      return err("no such file: #{path}") unless Fs.exists?(path)

      ok(Fs.read(path))
    end

    def write(args)
      return err("permission denied (try: sudo write ...)") unless cli_task.cred.root?

      path, *rest = args
      return err("usage: write <path> <data...>") if !path || rest.empty?

      data = rest.join(" ")
      Fs.write(path, data)
      ok({ "path" => path, "bytes" => data.bytesize })
    end

    def whoami_info
      cred = cli_task.cred
      {
        "uid"  => cred.uid,
        "euid" => cred.euid,
        "gid"  => cred.gid,
        "root" => cred.root?
      }
    end

    def sudo(args)
      subcmd, *subargs = args
      return err("usage: sudo <command> [args...]") unless subcmd

      original = cli_task.cred
      cli_task.assign_credentials(KProc::Credentials.root)
      begin
        dispatch("cmd" => subcmd, "args" => subargs)
      ensure
        cli_task.assign_credentials(original)
      end
    end

    def mounts_table
      Fs::Vfs.mounts.map do |m|
        {
          "mount_point" => m.mount_point,
          "backend"     => m.backend.class.to_s,
          "ns_id"       => m.ns_id,
          "flags"       => m.flags
        }
      end
    end
  end
end

CommandDispatcher.cli_task = cli_task

# ── Request/response loop — bidirectional, unlike the one-way dashboards ─────
stop     = false
unpacker = MessagePack::Unpacker.new

until stop
  begin
    chunk = client.readpartial(65536)
  rescue EOFError, Errno::ECONNRESET, IOError
    puts "  [cli_shell] shell disconnected"
    break
  end

  unpacker.feed_each(chunk) do |req|
    resp = CommandDispatcher.dispatch(req)

    begin
      client.write(MessagePack.pack(resp))
      client.flush
    rescue Errno::EPIPE, IOError
      stop = true
      next
    end

    stop = true if %w[exit quit].include?(req["cmd"].to_s)
  end
end

# ── Cleanup ────────────────────────────────────────────────────────────────────
KProc::SignalDelivery.post(cli_task, Kestowv::Signal::SIGTERM, sender_pid: 0, reason: :kernel) rescue nil
cli_task.transition(:zombie) rescue nil
KProc::Pid.release(cli_pid) rescue nil
Hub.unregister(SOCK_PATH)
client.close rescue nil
server.close rescue nil
File.delete(SOCK_PATH) rescue nil

puts ""
puts "  [cli_shell] Done"
