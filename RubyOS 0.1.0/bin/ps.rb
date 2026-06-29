# frozen_string_literal: true

# RubyOS 0.1.0 — bin/ps.rb

def ps(*)
  KernelClient.print_kernel_response(KernelClient.request("ps"))
end
