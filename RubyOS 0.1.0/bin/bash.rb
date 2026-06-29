# frozen_string_literal: true

# RubyOS 0.1.0 — bin/bash.rb
#
# Host-passthrough exception, unchanged from Rubian 3.1.0: Rubian is a
# real standalone CRuby process with genuine host access (like running
# irb standalone), so this command drops straight to a real shell
# instead of going through the Kestowv kernel.

def bash(*)
  system("bash")
end
