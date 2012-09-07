require 'ladle'

require 'java'

module Ladle
  ##
  # Implementations of platform-specific behaviors for JRuby.
  #
  # This separate strategy is necessary because you can't
  # `Process.waitpid2` on the PID returned by JRuby's `IO.popen4`.
  class JRubyProcess
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
      # You can't wait for the PID returned by JRuby's IO.popen4, so
      # this is necessary.
      cmd = @command_and_args.collect(&:to_s).to_java(:string)
      @process = Java::JavaLang::ProcessBuilder.new(
        cmd
      ).start

      [
        # java.util.Process flips the meanings of "in" and "out"
        # relative to popen3
        @process.output_stream.to_io,
        @process.input_stream.to_io,
        @process.error_stream.to_io
      ]
    end

    ##
    # Wait for the process to finish.
    #
    # @return [Fixnum] the return status of the process.
    def wait
      @process.waitFor
    end

    ##
    # Send signal 15 to the process.
    #
    # @return [void]
    def stop_gracefully
      begin
        Process.kill 15, pid
      rescue Errno::ESRCH
        # already gone
      end
    end

    ##
    # @return [Fixnum] the PID for the process
    def pid
      @pid ||= Java::OrgJrubyUtil::ShellLauncher.getPidFromProcess(@process)
    end
  end
end
