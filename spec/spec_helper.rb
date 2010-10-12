require 'bundler'
Bundler.setup

require 'rspec'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'ladle'

module Ladle::RSpec
  module Tmpdir
    def tmpdir
      @tmpdir ||= begin
                    name = File.expand_path("../../tmp/specs", __FILE__)
                    FileUtils.mkdir_p name
                    name
                  end
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
