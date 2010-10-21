require 'ladle'

require 'open4'

module Ladle
  ##
  # Implementations of platform-specific process handling behaviors for Ruby.
  class RubyProcess
    ##
    # Create a new process for the given command and its args.
    def initialize(*command_and_args)
      @command_and_args = command_and_args
    end

    ##
    # Start the process and return pipes to its standard streams.
    #
    # @return [[IO, IO, IO]] stdin, stdout, and stderr for the running process.
    def popen
      @pid, i, o, e = Open4.open4(@command_and_args.join(' '))
      [i, o, e]
    end

    ##
    # Wait for the process to finish.
    #
    # @return [Fixnum] the return status of the process.
    def wait
      Process.waitpid2(@pid)[1]
    end

    ##
    # Send signal 15 to the process.
    #
    # @return [void]
    def stop_gracefully
      Process.kill 15, pid
    end

    ##
    # @return [Fixnum] the PID for the process
    def pid
      @pid
    end
  end
end
