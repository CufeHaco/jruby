# frozen_string_literal: true

# RubyOS 0.1.0 — bin/whoami.rb

def whoami(*)
  KernelClient.print_kernel_response(KernelClient.request("whoami"))
end
