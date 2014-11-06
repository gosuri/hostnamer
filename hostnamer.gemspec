# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hostnamer/hostnamer"

Gem::Specification.new do |spec|
  spec.name          = "hostnamer"
  spec.version       = Hostnamer::VERSION
  spec.authors       = ["Greg Osuri"]
  spec.email         = ["gosuri@gmail.com"]
  spec.summary       = %q{cluster member discovery and registration tool for Route 53}
  spec.description   = %q{Hostnamer is a cluster member discovery and registration tool for Route 53. It discovers other cluster members using an incremental DNS search and self registers with a unique identifier.}

  spec.homepage      = "https://github.com/gosuri/hostnamer"
  spec.license       = "MIT"

  spec.files         = %w(README.md bin/hostnamer lib/hostnamer/hostnamer.rb)
  spec.executables   = %w(hostnamer)
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
end
