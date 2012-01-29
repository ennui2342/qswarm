require 'andand'
require 'eventmachine'

require 'qswarm/agent'
require 'qswarm/broker'

module Qswarm
  class Swarm
    include Qswarm::Loggable

    def self.load(config)
      dsl = new
      dsl.instance_eval(File.read(config), config)
      dsl
    end

    def initialize
      @agents = []
      $fqdn = Socket.gethostbyname(Socket.gethostname).first
      @brokers = {}
    end

    def log
      logger
    end

    def agent(name, &block)
      logger.info "Registering agent: #{name}"
      @agents << Qswarm::Agent.new(self, name, &block)
    end

    def broker(name, &block)
      logger.info "Registering broker: #{name}"
      @brokers[name] = Qswarm::Broker.new(name, &block)
    end

    def get_broker(name)
      @brokers[name]
    end

    def run
      EventMachine.run do
        @agents.map { |a| a.run }
      end
    end
  end
end
