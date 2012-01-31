require 'qswarm/broker'
require 'qswarm/listener'

module Qswarm
  class Agent
    include Qswarm::Loggable

    attr_reader :swarm, :name

    def initialize(swarm, name, args, &block)
      @swarm              = swarm
      @name               = name.to_s
      @brokers            = {}
      @listeners          = []
      @args               = args

      unless args.nil?
        case args.delete :type
        when :esper
          require 'java'

          require 'esper-4.5.0/esper-4.5.0.jar'
          require 'esper-4.5.0/esper/lib/commons-logging-1.1.1.jar'
          require 'esper-4.5.0/esper/lib/antlr-runtime-3.2.jar'
          require 'esper-4.5.0/esper/lib/cglib-nodep-2.2.jar'
          require 'esper-4.5.0/esper/lib/log4j-1.2.16.jar'

          include_class 'com.espertech.esper.client.EPRuntime'
          include_class 'com.espertech.esper.client.EPServiceProviderManager'
          include_class 'com.espertech.esper.client.EPServiceProvider'
          include_class 'com.espertech.esper.client.EPStatement'

          include_class 'com.espertech.esper.client.UpdateListener'
          include_class 'com.espertech.esper.client.EventBean'
          include_class 'org.apache.commons.logging.Log'
          include_class 'org.apache.commons.logging.LogFactory'
        end
      end

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
