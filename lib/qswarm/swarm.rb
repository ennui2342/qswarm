require 'andand'
require 'eventmachine'

module Qswarm
  class Swarm
    include Qswarm::DSL

    dsl :agent

    def initialize(config)
      @agents = []
      $fqdn = Socket.gethostbyname(Socket.gethostname).first

      dsl_load(config)
    end

    def agent(name, args = nil, &block)
      Qswarm.logger.info "Registering agent: #{name.inspect}"
      @agents << Qswarm::Agent.new(self, name, args, &block)
    end

    def run
      EventMachine.run do
        @agents.map { |a| a.run }
      end
    end
  end
end
