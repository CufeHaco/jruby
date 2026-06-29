# frozen_string_literal: true

# RubyOS 0.1.0 — bin/cat.rb

def cat(*args)
  KernelClient.print_kernel_response(KernelClient.request("cat", args))
end
