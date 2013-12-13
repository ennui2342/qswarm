# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "qswarm/version"

Gem::Specification.new do |s|
  s.name        = "qswarm"
  s.version     = Qswarm::VERSION
  s.authors     = ["Mark Cheverton"]
  s.email       = ["mark.cheverton@ecafe.org"]
  s.homepage    = "http://github.com/ennui2342/qswarm"
  s.summary     = %q{Streaming event processing DSL for Ruby}
  s.description = %q{Defines a DSL to allow stream processing from various sources for output to various sinks}

  s.rubyforge_project = "qswarm"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"

  s.add_dependency 'eventmachine'
  s.add_dependency 'amqp'
  s.add_dependency 'uuid'
  s.add_dependency 'json'
  s.add_dependency 'andand'
  s.add_dependency 'nokogiri'
  s.add_dependency 'tweetstream'
  s.add_dependency 'twitter'
end
