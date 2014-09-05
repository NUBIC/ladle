require File.expand_path("../../spec_helper.rb", __FILE__)

require 'net/ldap'

describe Ladle, "::Server" do
  def create_server(opts = {})
    default_opts = { :tmpdir => tmpdir }.merge(
      ENV['LADLE_TRACE'] ? { :verbose => true } : { :quiet => true })
    Ladle::Server.new(default_opts.merge(opts))
  end

  def should_be_running
    s = nil
    expect { s = TCPSocket.new('localhost', @server.port) }.
      not_to raise_error
    s.close if s
  end

  def should_not_be_running
    s = nil
    expect { s = TCPSocket.new('localhost', @server.port) }.
      to raise_error(/Connection refused/)
    s.close if s
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
    expect(left_over_pids).to be_empty
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
        expect(Ladle::Server.new.port).to eq(3897)
      end

      it "can be overridden" do
        expect(Ladle::Server.new(:port => 4200).port).to eq(4200)
      end
    end

    describe ":domain" do
      it "defaults to dc=example,dc=org" do
        expect(Ladle::Server.new.domain).to eq("dc=example,dc=org")
      end

      it "can be overridden" do
        expect(Ladle::Server.new(:domain => "dc=northwestern,dc=edu").domain).
          to eq("dc=northwestern,dc=edu")
      end

      it "rejects a domain that doesn't start with 'dc='" do
        expect { Ladle::Server.new(:domain => "foo") }.
          to raise_error("The domain component must start with 'dc='.  'foo' does not.")
      end
    end

    describe ":ldif" do
      it "defaults to lib/ladle/default.ldif" do
        expect(Ladle::Server.new.ldif).to match(%r{lib/ladle/default.ldif$})
      end

      it "can be overridden" do
        ldif_file = "#{tmpdir}/foo.ldif"
        FileUtils.touch ldif_file
        expect(Ladle::Server.new(:ldif => ldif_file).ldif).to eq(ldif_file)
      end

      it "fails if the file can't be read" do
        expect { Ladle::Server.new(:ldif => "foo/bar.ldif") }.
          to raise_error("Cannot read specified LDIF file foo/bar.ldif.")
      end
    end

    describe ":verbose" do
      it "defaults to false" do
        expect(Ladle::Server.new.verbose?).to be_falsey
      end

      it "can be overridden" do
        expect(Ladle::Server.new(:verbose => true).verbose?).to be_truthy
      end
    end

    describe ":quiet" do
      it "defaults to false" do
        expect(Ladle::Server.new.quiet?).to be_falsey
      end

      it "can be overridden" do
        expect(Ladle::Server.new(:quiet => true).quiet?).to be_truthy
      end
    end

    describe ":timeout" do
      it "defaults to 60 seconds" do
        expect(Ladle::Server.new.timeout).to eq(60)
      end

      it "can be overridden" do
        expect(Ladle::Server.new(:timeout => 87).timeout).to eq(87)
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
        expect(Ladle::Server.new.tmpdir).to eq(tmpdir('foo'))
      end

      it "defaults to TEMPDIR if set" do
        ENV["TEMPDIR"] = tmpdir('baz')
        expect(Ladle::Server.new.tmpdir).to eq(tmpdir('baz'))
      end

      it "prefers the explicitly provided value" do
        ENV["TMPDIR"] = tmpdir('quux')
        ENV["TEMPDIR"] = tmpdir('bar')
        expect(Ladle::Server.new(:tmpdir => tmpdir('zap')).tmpdir).
          to eq(tmpdir('zap'))
      end

      it "must be specified somehow" do
        expect(Ladle::Server.new.tmpdir).to eq(Dir.tmpdir)
      end

      it "must exist" do
        expect { Ladle::Server.new(:tmpdir => 'whatever') }.
          to raise_error(/Tmpdir "whatever" does not exist./)
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
        expect(Ladle::Server.new.java_bin).to eq("java")
      end

      it "defaults to JAVA_HOME/bin/java if available" do
        ENV["JAVA_HOME"] = tmpdir('myjdk')
        expect(Ladle::Server.new.java_bin).to eq("#{tmpdir}/myjdk/bin/java")
      end

      it "can be overridden" do
        expect(Ladle::Server.new(:java_bin => File.join(tmpdir('openjdk'), "jre")).java_bin).
          to eq("#{tmpdir}/openjdk/jre")
      end
    end

    describe ":allow_anonymous" do
      it "defaults to true" do
        expect(Ladle::Server.new.allow_anonymous?).to be_truthy
      end

      it "can be overridden" do
        expect(Ladle::Server.new(:allow_anonymous => false).allow_anonymous?).to be_falsey
      end
    end

    describe ":custom_schemas" do
      it "defaults to an empty list" do
        expect(Ladle::Server.new.custom_schemas).to eq([])
      end

      it "can be set from one file name" do
        expect(Ladle::Server.new(:custom_schemas => "net.example.HappySchema").
          custom_schemas).to eq(%w(net.example.HappySchema))
      end

      it "can be set from a list" do
        expect(Ladle::Server.new(:custom_schemas => ["net.example.HappySchema", "net.example.SadSchema"]).
          custom_schemas).to eq(%w(net.example.HappySchema net.example.SadSchema))
      end
    end

    describe ":additional_classpath" do
      it "defaults to an empty list" do
        expect(Ladle::Server.new.additional_classpath).to eq([])
      end

      it "can be set from one entry" do
        expect(Ladle::Server.new(:additional_classpath => "foo").
          additional_classpath).to eq(%w(foo))
      end

      it "can be set from a list" do
        expect(Ladle::Server.new(:additional_classpath => ["bar", "baz"]).
          additional_classpath).to eq(%w(bar baz))
      end
    end
  end

  describe "running" do
    it "blocks until the server is up" do
      @server.start
      should_be_running
    end

    it "returns the server object" do
      expect(@server.start).to be(@server)
    end

    it "is safe to invoke twice (in the same thread)" do
      @server.start
      expect { @server.start }.not_to raise_error
    end

    it "can be stopped then started again" do
      @server.start
      @server.stop
      @server.start
      should_be_running
    end

    it "throws an exception when the server doesn't start up" do
      old_stderr, $stderr = $stderr, StringIO.new

      @server = create_server(:more_args => ["--fail", "before_start"])
      expect { @server.start }.to raise_error(/LDAP server failed to start/)
      expect($stderr.string).to eq("ApacheDS process failed: FATAL: Expected failure for testing\n")

      $stderr = old_stderr
    end

    it "times out after the specified interval" do
      @server = create_server(:timeout => 3, :more_args => %w(--fail hang))
      expect { @server.start }.
        to raise_error(/LDAP server startup did not complete within 3 seconds/)
    end

    it "should use the specified port" do
      @server = create_server(:port => 45678).start
      should_be_running
    end

    it "uses the specified tmpdir" do
      target = tmpdir('baz')
      @server = create_server(:tmpdir => target).start
      expect(Dir["#{target}/ladle-server-*"].size).to eq(1)
    end

    it "cleans up the tmpdir afterward" do
      target = tmpdir('quux')
      @server = create_server(:tmpdir => target).start
      @server.stop
      expect(Dir["#{target}/ladle-server-*"].size).to eq(0)
    end
  end

  describe "LDAP implementation" do
    def with_ldap(params={})
      @server.start
      # We don't use Net::LDAP.open because it seems to leak sockets,
      # at least on Linux and with version 0.0.4 of the library.
      ldap = Net::LDAP.new({
          :host => 'localhost', :port => @server.port,
          :auth => { :method => :anonymous }
        }.merge(params))
      yield ldap
    end

    def ldap_search(filter, base=nil)
      with_ldap { |ldap|
        ldap.search(
          :base => base || 'dc=example,dc=org',
          :filter => filter
        ).tap {
          expect(ldap.get_operation_result.code).to eq(0) # success
        }
      }
    end

    describe "data" do
      describe "the default set" do
        it "has 26 people" do
          expect(ldap_search(Net::LDAP::Filter.pres('uid')).size).to eq(26)
        end

        it "has 1 group" do
          expect(ldap_search(Net::LDAP::Filter.pres('ou')).size).to eq(1)
        end

        it "has given names" do
          expect(ldap_search(Net::LDAP::Filter.pres('uid')).
            select { |res| !res[:givenname] || res[:givenname].empty? }).to eq([])
        end

        it "has e-mail addresses" do
          expect(ldap_search(Net::LDAP::Filter.pres('uid')).
            select { |res| !res[:mail] || res[:mail].empty? }).to eq([])
        end

        it "can be searched by value" do
          expect(ldap_search(Net::LDAP::Filter.eq(:givenname, 'Josephine')).
            collect { |res| res[:uid].first }).to eq(%w(jj243))
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
          expect(ldap_search(Net::LDAP::Filter.pres('ou'), 'dc=example,dc=net').
            collect { |result| result[:ou].first }).to eq(["animals"])
        end

        it "has the individuals provided by the other LDIF" do
          expect(ldap_search(Net::LDAP::Filter.pres('uid'), 'dc=example,dc=net').
            collect { |result| result[:givenname].first }.sort).to eq(%w(Ada Bob))
        end
      end

      describe "with a custom schema" do
        before do
          @server = create_server(
            :ldif => File.expand_path("../animals-custom.ldif", __FILE__),
            :domain => "dc=example,dc=net",
            :custom_schemas => File.expand_path("../animals-custom-schema.ldif", __FILE__)
          )
        end

        it "has the data defined in the schema" do
          expect(ldap_search(Net::LDAP::Filter.pres('species'), 'dc=example,dc=net').
            collect { |r| r[:species].first }.sort).to eq(["Meles meles", "Orycteropus afer"])
        end
      end
    end

    describe "binding" do
      it "works with a valid password" do
        with_ldap do |ldap|
          ldap.authenticate("uid=hh153,ou=people,dc=example,dc=org", "hatfield".reverse)
          expect(ldap.bind).to be_truthy
        end
      end

      it "does not work with an invalid password" do
        with_ldap do |ldap|
          ldap.authenticate("uid=hh153,ou=people,dc=example,dc=org", "mccoy".reverse)
          expect(ldap.bind).to be_falsey
        end
      end

      describe "with anonymous binding disabled" do
        before do
          @server = create_server(:allow_anonymous => false)
        end

        it "will not bind anonymously" do
          with_ldap do |ldap|
            # anonymous bind is successful even with anonymous access
            # off, but searches fail appropriately
            ldap.search(:filter => Net::LDAP::Filter.pres('uid'), :base => 'dc=example,dc=org')
            expect(ldap.get_operation_result.code).to eq(49) # invalid credentials
          end
        end

        it "will bind with a username and valid password" do
          with_ldap do |ldap|
            ldap.authenticate("uid=kk891,ou=people,dc=example,dc=org", "enilk")
            expect(ldap.bind).to be_truthy
          end
        end

        it "will not bind with a username and invalid password" do
          with_ldap do |ldap|
            ldap.authenticate("uid=kk891,ou=people,dc=example,dc=org", "kevin")
            expect(ldap.bind).to be_falsey
          end
        end

        it "permits searches for authenticated users" do
          with_ldap do |ldap|
            ldap.authenticate("uid=kk891,ou=people,dc=example,dc=org", "enilk")
            expect(ldap.search(:filter => Net::LDAP::Filter.pres('uid'), :base => 'dc=example,dc=org').size).
              to eq(26)
          end
        end
      end
    end
  end
end
