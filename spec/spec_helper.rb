require 'bundler'
Bundler.setup

require 'rspec'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'ladle'

module Ladle::RSpec
  module Tmpdir
    def tmpdir(path=nil)
      @tmpdir ||= File.expand_path("../../tmp/specs", __FILE__)
      full = path ? File.join(@tmpdir, path) : @tmpdir
      FileUtils.mkdir_p full
      full
    end

    def rm_tmpdir
      if @tmpdir
        FileUtils.rm_rf @tmpdir
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Ladle::RSpec::Tmpdir)
  config.after do
    rm_tmpdir
  end
end
