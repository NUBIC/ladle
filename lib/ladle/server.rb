require 'ladle'

module Ladle
  ##
  # Controller for Ladle's core feature, the embedded LDAP server.
  class Server
    ##
    # The port from which this server will be available.
    # @return [Fixnum]
    attr_reader :port

    ##
    # The domain for the served data.
    # @return [String]
    attr_reader :domain

    ##
    # The filename of the LDIF data loaded into this server before it
    # started.
    # @return [String]
    attr_reader :ldif

    ##
    # If the controller will print anything about what it is doing to
    # stderr.
    # @return [Boolean]
    attr_reader :quiet

    ##
    # Whether the controller will print detailed information about
    # what it is doing to stderr.
    # @return [Boolean]
    attr_reader :verbose

    ##
    # The time to wait for the server to start up before giving up
    # (seconds).
    # @return [Fixnum]
    attr_reader :timeout

    ##
    # @param [Hash] opts the options for the server
    # @option opts [Fixnum] :port (3897) The port to serve from.
    # @option opts [String] :ldif ({path to the gem}/lib/ladle/default.ldif)
    #   The filename of the LDIF-formatted data to use for this
    #   server.  If provide your own data, be sure to set the
    #   :domain option to match.
    # @option opts [String] :domain ("dc=example,dc=org") the domain
    #   for the data provided in the :ldif option.
    def initialize(opts={})
      @port = opts[:port] || 3897
      @domain = opts[:domain] || "dc=example,dc=org"
      @ldif = opts[:ldif] || File.expand_path("../default.ldif", __FILE__)
      @quiet = false
      @verbose = true
      @timeout = 30

      unless @domain =~ /^dc=/
        raise "The domain component must start with 'dc='.  '#{@domain}' does not."
      end

      unless File.readable?(@ldif)
        raise "Cannot read specified LDIF file #{@ldif}."
      end
    end

    ##
    # Starts up the server in a separate process.  This method will
    # not return until the server is listening on the specified port.
    # The same {Server} instance can be started and stopped multiple
    # times, but the runs will be independent.
    def start
      log "Starting server on #{port}"
      trace "  Server command: #{server_cmd}"
      @java_in, @java_out, java_err = Open3.popen3(server_cmd)
      @running = true
      @err_printer = Thread.new do
        while l = java_err.readline
          $stderr.puts "Java Err: #{l}"
        end
      end

      trace "Looking for STARTED"
      until (l = @java_out.readline) =~ /STARTED/
        puts l
        sleep 0.5
      end

      at_exit { stop }
    end

    def stop
      @java_in.puts("STOP")
    end

    private

    def log(msg)
      $stderr.puts(msg) unless quiet
    end

    def trace(msg)
      $stderr.puts(msg) if verbose && !quiet
    end

    def server_cmd
      [
        "java",
        "-cp", classpath,
        "net.detailedbalance.ladle.Main"
      ].join(' ')
    end

    def classpath
      (
        # ApacheDS
        Dir[File.expand_path("../apacheds/*.jar", __FILE__)] +
        # Wrapper code
        [File.expand_path("../java", __FILE__)]
      ).join(':')
    end
  end
end
