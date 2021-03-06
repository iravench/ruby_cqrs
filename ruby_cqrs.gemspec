# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ruby_cqrs/version"

Gem::Specification.new do |s|
  s.name          = "ruby_cqrs"
  s.version       = RubyCqrs::VERSION
  s.authors       = ["Raven Chen"]
  s.email         = ["ravenchen.cn@gmail.com"]

  s.platform      = Gem::Platform::RUBY
  s.license       = "MIT"
  s.summary       = "ruby_cqrs-#{RubyCqrs::VERSION}"
  s.description   = "a ruby implementation of cqrs, using event sourcing"
  s.homepage      = "https://github.com/iravench/ruby_cqrs"

  s.files             = `git ls-files -- lib/*`.split("\n")
  s.files            += ["License.txt"]
  s.test_files        = `git ls-files -- spec/*`.split("\n")
  s.executables       = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.extra_rdoc_files  = [ "README.md" ]
  s.rdoc_options      = ["--charset=UTF-8"]
  s.require_path      = ["lib"]

  s.add_runtime_dependency "uuidtools", "2.1.5"
  s.add_runtime_dependency "activesupport", "4.2.1"
  s.add_runtime_dependency "beefcake", "1.0.0"
  s.add_runtime_dependency "contracts", "0.9.0"
end
