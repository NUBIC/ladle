require File.expand_path("../../spec_helper.rb", __FILE__)

require 'net/ldap'

describe Ladle, "::Server" do
  def create_server(opts = {})
    default_opts = { :tmpdir => tmpdir }.merge(
      ENV['LADLE_TRACE'] ? { :verbose => true } : { :quiet => true })
    Ladle::Server.new(default_opts.merge(opts))
  end

  def should_be_running
    lambda { TCPSocket.new('localhost', @server.port) }.
      should_not raise_error
  end

  def should_not_be_running
    lambda { TCPSocket.new('localhost', @server.port) }.
      should raise_error
  end

  before do
    @server = create_server
    should_not_be_running # fail early
  end

  after do
    @server.stop

    left_over_pids = `ps`.split("\n").grep(/net.detailedbalance.ladle.Main/).
      collect { |line| line.split(/\s+/)[0].to_i }
    left_over_pids.each { |pid|
      $stderr.puts "Killing leftover process #{pid}"
      Process.kill 15, pid
    }
    left_over_pids.should be_empty
  end

  describe "initialization of" do
    def preserve_and_wipe_env(*env_vars)
      @old_env = env_vars.inject({}) { |e, k| e[k] = ENV[k]; e }
      @old_env.keys.each { |k| ENV[k] = nil }
    end

    def restore_env
      @old_env.each { |k, v| ENV[k] = v }
    end

    describe ":port" do
      it "defaults to 3897" do
        Ladle::Server.new.port.should == 3897
      end

      it "can be overridden" do
        Ladle::Server.new(:port => 4200).port.should == 4200
      end
    end

    describe ":domain" do
      it "defaults to dc=example,dc=org" do
        Ladle::Server.new.domain.should == "dc=example,dc=org"
      end

      it "can be overridden" do
        Ladle::Server.new(:domain => "dc=northwestern,dc=edu").domain.
          should == "dc=northwestern,dc=edu"
      end

      it "rejects a domain that doesn't start with 'dc='" do
        lambda { Ladle::Server.new(:domain => "foo") }.
          should raise_error("The domain component must start with 'dc='.  'foo' does not.")
      end
    end

    describe ":ldif" do
      it "defaults to lib/ladle/default.ldif" do
        Ladle::Server.new.ldif.should =~ %r{lib/ladle/default.ldif$}
      end

      it "can be overridden" do
        ldif_file = "#{tmpdir}/foo.ldif"
        FileUtils.touch ldif_file
        Ladle::Server.new(:ldif => ldif_file).ldif.should == ldif_file
      end

      it "fails if the file can't be read" do
        lambda { Ladle::Server.new(:ldif => "foo/bar.ldif") }.
          should raise_error("Cannot read specified LDIF file foo/bar.ldif.")
      end
    end

    describe ":verbose" do
      it "defaults to false" do
        Ladle::Server.new.verbose?.should be_false
      end

      it "can be overridden" do
        Ladle::Server.new(:verbose => true).verbose?.should be_true
      end
    end

    describe ":quiet" do
      it "defaults to false" do
        Ladle::Server.new.quiet?.should be_false
      end

      it "can be overridden" do
        Ladle::Server.new(:quiet => true).quiet?.should be_true
      end
    end

    describe ":timeout" do
      it "defaults to 15 seconds" do
        Ladle::Server.new.timeout.should == 15
      end

      it "can be overridden" do
        Ladle::Server.new(:timeout => 27).timeout.should == 27
      end
    end

    describe ":tmpdir" do
      before do
        preserve_and_wipe_env("TMPDIR", "TEMPDIR")
      end

      after do
        restore_env
      end

      it "defaults to TMPDIR if set" do
        ENV["TMPDIR"] = tmpdir('foo')
        Ladle::Server.new.tmpdir.should == tmpdir('foo')
      end

      it "defaults to TEMPDIR if set" do
        ENV["TEMPDIR"] = tmpdir('baz')
        Ladle::Server.new.tmpdir.should == tmpdir('baz')
      end

      it "prefers the explicitly provided value" do
        ENV["TMPDIR"] = tmpdir('quux')
        ENV["TEMPDIR"] = tmpdir('bar')
        Ladle::Server.new(:tmpdir => tmpdir('zap')).tmpdir.
          should == tmpdir('zap')
      end

      it "must exist" do
        lambda { Ladle::Server.new(:tmpdir => 'whatever') }.
          should raise_error(/Tmpdir "whatever" does not exist./)
      end

      it "must be specified somehow" do
        lambda { Ladle::Server.new }.
          should raise_error(/Cannot guess tmpdir from the environment.  Please specify it./)
      end
    end

    describe ":java" do
      before do
        preserve_and_wipe_env("JAVA_HOME")
      end

      after do
        restore_env
      end

      it "relies on the path with no JAVA_HOME" do
        Ladle::Server.new.java_bin.should == "java"
      end

      it "defaults to JAVA_HOME/bin/java if available" do
        ENV["JAVA_HOME"] = tmpdir('myjdk')
        Ladle::Server.new.java_bin.should == "#{tmpdir}/myjdk/bin/java"
      end

      it "can be overridden" do
        Ladle::Server.new(:java_bin => File.join(tmpdir('openjdk'), "jre")).java_bin.
          should == "#{tmpdir}/openjdk/jre"
      end
    end
  end

  describe "running" do
    it "blocks until the server is up" do
      @server.start
      should_be_running
    end

    it "returns the server object" do
      @server.start.should be(@server)
    end

    it "is safe to invoke twice (in the same thread)" do
      @server.start
      lambda { @server.start }.should_not raise_error
    end

    it "can be stopped then started again" do
      @server.start
      @server.stop
      @server.start
      lambda { TCPSocket.new('localhost', @server.port) }.
        should_not raise_error
    end

    it "throws an exception when the server doesn't start up" do
      old_stderr, $stderr = $stderr, StringIO.new

      @server = create_server(:more_args => ["--fail", "before_start"])
      lambda { @server.start }.should raise_error(/LDAP server failed to start/)
      $stderr.string.should == "ApacheDS process failed: FATAL: Expected failure for testing\n"

      $stderr = old_stderr
    end

    it "times out after the specified interval" do
      @server = create_server(:timeout => 3, :more_args => %w(--fail hang))
      lambda { @server.start }.
        should raise_error(/LDAP server startup did not complete within 3 seconds/)
    end

    it "should use the specified port" do
      @server = create_server(:port => 45678).start
      should_be_running
    end

    it "uses the specified tmpdir" do
      target = tmpdir('baz')
      @server = create_server(:tmpdir => target).start
      Dir["#{target}/ladle-server-*"].size.should == 1
    end

    it "cleans up the tmpdir afterward" do
      target = tmpdir('quux')
      @server = create_server(:tmpdir => target).start
      @server.stop
      Dir["#{target}/ladle-server-*"].size.should == 0
    end
  end

  describe "data" do
    before do
      pending "Net::LDAP doesn't work on 1.9" if RUBY_VERSION =~ /1.9/
    end

    def with_ldap
      @server.start
      Net::LDAP.open(ldap_parameters) do |ldap|
        return yield ldap
      end
    end

    def ldap_search(filter, base=nil)
      with_ldap { |ldap|
        ldap.search(
          :base => base || 'dc=example,dc=org',
          :filter => filter
        )
      }
    end

    def ldap_parameters
      @ldap_parameters ||= {
        :host => 'localhost', :port => @server.port,
        :auth => { :method => :anonymous }
      }
    end

    describe "the default set" do
      it "has 26 people" do
        ldap_search(Net::LDAP::Filter.pres('uid')).should have(26).people
      end

      it "has 1 group" do
        ldap_search(Net::LDAP::Filter.pres('ou')).should have(1).group
      end

      it "has given names" do
        ldap_search(Net::LDAP::Filter.pres('uid')).
          select { |res| !res[:givenname] || res[:givenname].empty? }.should == []
      end

      it "has e-mail addresses" do
        ldap_search(Net::LDAP::Filter.pres('uid')).
          select { |res| !res[:mail] || res[:mail].empty? }.should == []
      end

      it "can be searched by value" do
        ldap_search(Net::LDAP::Filter.eq(:givenname, 'Josephine')).
          collect { |res| res[:uid].first }.should == %w(jj243)
      end
    end

    describe "with a provided set" do
      before do
        @server = create_server(
          :domain => "dc=example,dc=net",
          :ldif => File.expand_path("../animals.ldif", __FILE__)
        )
      end

      it "has the groups provided by the other LDIF" do
        ldap_search(Net::LDAP::Filter.pres('ou'), 'dc=example,dc=net').
          collect { |result| result[:ou].first }.should == ["animals"]
      end

      it "has the individuals provided by the other LDIF" do
        ldap_search(Net::LDAP::Filter.pres('uid'), 'dc=example,dc=net').
          collect { |result| result[:givenname].first }.sort.should == %w(Ada Bob)
      end
    end
  end
end
