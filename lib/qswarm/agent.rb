require 'qswarm/broker'
require 'qswarm/listener'

module Qswarm
  class Agent
    include Qswarm::Loggable

    attr_reader :swarm, :name

    def initialize(swarm, name, &block)
      @swarm              = swarm
      @name               = name.to_s
      @brokers            = {}
      @listeners          = []

      self.instance_eval(&block)
    end

    def listen(name, args = nil, &block)
      logger.info "Registering listener: #{name}"
      @listeners << Qswarm::Listener.new(self, name, args, &block)
    end

    def broker(name, &block)
      logger.info "Registering broker: #{name}"
      @brokers[name] = Qswarm::Broker.new(name, &block)
    end

    def get_broker(name)
      @brokers[name] || @swarm.get_broker(name)
    end

    def bind
      logger.info "Binding to exchange"
    end

    def run
      @listeners.map { |l| l.run }
    end
  end
end
