require 'json'

require 'qswarm/dsl'

module Qswarm
  class Speaker
    include Qswarm::Loggable
    extend Qswarm::DSL

    dsl_accessor :broker
    attr_reader :agent, :metadata, :heard, :name

    def initialize(listener, name, &block)
      @listener = listener
      @agent    = @listener.agent
      @name     = name.to_s unless name.nil?
      @block    = block

    end

    def parse(metadata, payload)
      @metadata = metadata
      case @listener.format
      when :json
        @heard = JSON.parse(payload)
      else
        @heard = payload
      end

      self.instance_eval(&@block)
    rescue JSON::ParserError
      error = "JSON::ParserError on #{payload.inspect}"
      logger.error error
      publish :errors, :text, "errors.#{@agent.name}.#{$fqdn}", error
    end

    def log(msg)
      logger.info "[#{@agent.name}] #{msg}"
    end

    def inject(format = :text, msg)
      logger.debug "[#{@agent.name}] Sending '#{msg}' to broker #{get_broker(@broker).name}/#{@name}"
      publish @broker, format, @name, msg
      log msg if format == :text
    end

    def get_broker(name)
      @listener.get_broker(name)
    end
    
    def run
    end

    private

    def publish(broker_name, format, routing_key, msg)
      case format
      when :json
        get_broker(broker_name).exchange.publish JSON.generate(msg), :routing_key => routing_key
      when :text
        get_broker(broker_name).exchange.publish msg, :routing_key => routing_key
      end    
    end
  end
end
