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

      unless @domain =~ /^dc=/
        raise "The domain component must start with 'dc='.  '#{@domain}' does not."
      end

      unless File.readable?(@ldif)
        raise "Cannot read specified LDIF file #{@ldif}."
      end
    end
  end
end
