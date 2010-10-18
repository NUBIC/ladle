##
# Ladle dishes out steaming helpings of lightweight directory access
# (LDAP) for use in testing with rspec, cucumber, or any other ruby
# test framework.
#
# This is the namespace for Ladle's implementation.
module Ladle
  autoload :VERSION, "ladle/version"
  autoload :Server, "ladle/server"

  autoload :RubyAdapter, "ladle/ruby_adapter"
end
