require File.expand_path("../../spec_helper.rb", __FILE__)

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
  end
end
