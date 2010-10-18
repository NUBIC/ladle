require 'ladle'

require 'open4'

module Ladle
  ##
  # Implementations of platform-specific behaviors for standard ruby.
  module RubyAdapter
    def self.popen4(command)
      Open4.popen4(command)
    end
  end
end
