require File.expand_path("../../spec_helper.rb", __FILE__)

describe Ladle, "::VERSION" do
  it "exists" do
    expect { Ladle::VERSION }.not_to raise_error
  end

  it "has 3 or 4 dot separated parts" do
    expect(Ladle::VERSION.split('.').size).to be_between(3, 4)
  end
end
