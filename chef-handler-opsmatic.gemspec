# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef/handler/opsmatic'

Gem::Specification.new do |spec|
  spec.name          = "chef-handler-opsmatic"
  spec.version       = Chef::Handler::Opsmatic::VERSION
  spec.authors       = ["Marcus Barczak"]
  spec.email         = ["support@opsmatic.com"]
  spec.summary       = %q{Chef report handler for sending run detail information to Opsmatic}
  spec.description   = %q{Chef report handler for sending run detail information to Opsmatic}
  spec.homepage      = "https://github.com/opsmatic/chef-handler-opsmatic"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "chef"
  spec.add_development_dependency "webmock"
end
