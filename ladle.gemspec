# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ladle/version"

Gem::Specification.new do |s|
  s.name        = "ladle"
  s.version     = Ladle::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Rhett Sutphin"]
  s.email       = ["rhett@detailedbalance.net"]
  s.homepage    = "http://github.com/rsutphin/ladle"
  s.summary     = %q{Dishes out steaming helpings of LDAP for fluid testing}
  s.description = %q{Provides an embedded LDAP server for BDD.  The embedded server is built with ApacheDS.}

  s.files         = Dir["{lib,spec}/**/*"] + Dir["*.md"] + Dir["*LICENSE"] + %w(NOTICE)
  s.test_files    = Dir["spec/**/*"]
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec", "~> 2.0.0"
end
