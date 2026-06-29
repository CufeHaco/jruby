# frozen_string_literal: true

# RubyOS 0.1.0 — bin/sudo.rb
#
# args[0] is the sub-command, the rest are its args. The kernel side
# (boot/cli_shell.rb's "sudo" handler) elevates the task's Cred to root
# for the duration of that one sub-command, then reverts it.

def sudo(*args)
  KernelClient.print_kernel_response(KernelClient.request("sudo", args))
end
