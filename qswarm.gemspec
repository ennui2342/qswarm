# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "qswarm/version"

Gem::Specification.new do |s|
  s.name        = "qswarm"
  s.version     = Qswarm::VERSION
  s.authors     = ["Mark Cheverton"]
  s.email       = ["mark.cheverton@ecafe.org"]
  s.homepage    = "http://github.com/ennui2342/qswarm"
  s.summary     = %q{Distributed queue based agents in Ruby}
  s.description = %q{Framework for writing distributed agents hanging off an AMQP message bus}

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
end
