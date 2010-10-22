require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'

RSpec::Core::RakeTask.new do |t|
  t.pattern = "spec/**/*_spec.rb"
end

task :spec => [:compile]

desc "Remove the compiled artifacts"
task :clean do
  Dir['**/*.class'].each { |fn| rm_rf fn }
end

desc "Compile the java adapter code"
task :compile do
  puts "Compiling java support code"
  jars = Dir['lib/ladle/apacheds/*.jar'].collect { |fn| File.expand_path(fn) }
  javac = ENV['JAVA_HOME'] ? ENV['JAVA_HOME'] + "/bin/javac" : "javac"
  one_cmd(
    javac, '-cp', "'#{jars.join(':')}'",
    ('-verbose' if Rake.application.options.trace),
    'lib/ladle/java/net/detailedbalance/ladle/*.java')
end

# build task is provided by bundler's gem helper
task :build => [:clean, :compile]

desc "Release both the Ruby and JRuby variants of Ladle"
task :release do
  system("rake -f meta.rakefile release")
end

desc "Run the yard server with automatic reloading enabled"
task :yard => ['yard:auto']

namespace :yard do
  YARD::Rake::YardocTask.new(:once) do |t|
    t.options = ["--title", "Ladle #{Ladle::VERSION}"]
  end

  task :auto do
    one_cmd("bundle exec yard server --reload")
  end

  desc "Remove the YARD cache and the generated docs"
  task :clean do
    rm_rf '.yardoc'
    rm_rf 'doc'
  end
end

def one_cmd(*cmd)
  str = cmd.compact.join(' ')
  puts str if Rake.application.options.trace
  system(str)
end
