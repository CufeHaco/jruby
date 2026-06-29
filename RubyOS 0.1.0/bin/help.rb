# frozen_string_literal: true

# RubyOS 0.1.0 — bin/help.rb

def help(*)
  KernelClient.print_kernel_response(KernelClient.request("help"))
end
