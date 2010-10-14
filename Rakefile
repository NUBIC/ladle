require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'

RSpec::Core::RakeTask.new do |t|
  t.pattern = "spec/**/*_spec.rb"
end

desc "Run the yard server with automatic reloading enabled"
task :yard => ['yard:auto']

namespace :yard do
  YARD::Rake::YardocTask.new(:once) do |t|
    t.options = ["--title", "Ladle #{Ladle::VERSION}"]
  end

  task :auto do
    system("bundle exec yard server --reload")
  end

  desc "Remove the YARD cache and the generated docs"
  task :clean do
    rm_rf '.yardoc'
    rm_rf 'doc'
  end
end
