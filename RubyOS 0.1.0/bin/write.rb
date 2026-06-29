# frozen_string_literal: true

# RubyOS 0.1.0 — bin/write.rb
#
# Privilege-gated on the kernel side: requires root, demonstrating the
# Kestowv credential boundary (see boot/cli_shell.rb's write handler).

def write(*args)
  KernelClient.print_kernel_response(KernelClient.request("write", args))
end
