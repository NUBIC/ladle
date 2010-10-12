require 'ladle'

module Ladle
  class Server
    attr_reader :port, :domain, :ldif

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
