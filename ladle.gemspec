# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ladle/version"

java = (RUBY_PLATFORM == 'java')

Gem::Specification.new do |s|
  s.name        = "ladle"
  s.version     = Ladle::VERSION
  s.platform    = java ? 'java' : 'ruby'
  s.authors     = ["Rhett Sutphin"]
  s.email       = ["rhett@detailedbalance.net"]
  s.homepage    = "http://github.com/rsutphin/ladle"
  s.summary     = %q{Dishes out steaming helpings of LDAP for fluid testing}
  s.description = %q{Provides an embedded LDAP server for BDD.  The embedded server is built with ApacheDS.}

  s.files         = Dir["{lib,spec}/**/*"] + Dir["*.md"] + Dir["*LICENSE"] + %w(NOTICE)
  s.test_files    = Dir["spec/**/*"]
  s.require_paths = ["lib"]

  s.add_dependency "open4", "~> 1.0" unless java
  s.add_development_dependency "rspec", "~> 2.0"
  s.add_development_dependency "yard", "~> 0.6.1"
  s.add_development_dependency java ? "maruku" : "rdiscount"
  s.add_development_dependency "net-ldap", "~> 0.1.1"
  s.add_development_dependency "ci_reporter", '~> 1.6'
  s.add_development_dependency 'rake', '~> 0.9.2'
end
