require File.expand_path("../../spec_helper.rb", __FILE__)

# require 'net/ldap'

describe Ladle, "::Server" do
  describe "initialization of" do
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
  end

  describe "running" do
    before do
      @server = Ladle::Server.new(:quiet => true)
    end

    after do
      @server.stop
    end

    it "should block until the server is up" do
      @server.start
      lambda { TCPSocket.new('localhost', @server.port) }.
        should_not raise_error
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
      @server = Ladle::Server.new(:more_args => ["--fail", "before_start"], :quiet => true)
      lambda { @server.start }.should raise_error(/LDAP server failed to start/)
    end

    it "should use the right port"
    it "should use the specified data"
  end
end
