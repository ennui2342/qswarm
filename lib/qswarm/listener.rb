require 'uuid'
require 'eventmachine'

require 'qswarm/dsl'
require 'qswarm/speaker'

module Qswarm
  class Listener
    include Qswarm::Loggable
    extend Qswarm::DSL

    dsl_accessor :name, :broker, :format
    attr_reader :agent

    def initialize(agent, name, args, &block)
      @agent    = agent
      @name     = name.to_s
      @speakers = []
      @sinks    = []
      @format   = :json
      @instances = nil

      @queue_args     = { :auto_delete => true, :durable => true, :exclusive => true }
      @subscribe_args = { :exclusive => false, :ack => false }

      @speaker = args.delete :speaker unless args.nil?

      # @subscribe_args.merge! args.delete(:subscribe) unless args.nil?
      @queue_args.merge! args unless args.nil?

      self.instance_eval(&block)
    end

    def bind(routing_key, options = nil)
      @bind = routing_key
      @queue_args.merge! options unless options.nil?
      logger.info "Binding listener #{@name} < #{routing_key}"
    end

    # Not sure about this
    def subscribe(*options)
      Array[*options].each { |o| @subscribe_args[o] = true }
    end

    def ack?
      @subscribe_args[:ack]
    end

    def swarm(instances = nil)
      @instances = instances
    end
   
    # Should this be subscribe options?
    def uniq
      @uuid = '-' + UUID.generate
    end

    def speak(name, args = nil, &block)
      if !args.nil?
        require "qswarm/speakers/#{args[:type].downcase}"
        @speakers << eval("Qswarm::Speakers::#{args[:type].capitalize}").new(self, name, &block)
      else
        @speakers << Qswarm::Speaker.new(self, name, &block)
      end
      logger.info "Registering speaker: #{name} < #{@name}"
    end

    def get_broker(name = nil)
      name ||= @broker
      @agent.get_broker(name)
    end

    def run
      # Any setup that needs to be done
      @speakers.map { |s| s.run }
      
      @bind ||= @name
      logger.info "Listening on #{@name} < #{@bind}"

      get_broker.channel(@name, @bind).prefetch(@instances) unless @instances.nil?
      get_broker.queue(@name + @uuid ||= '', @bind, @queue_args).subscribe(@subscribe_args) do |metadata, payload|
        logger.debug "[#{@agent.name}] Received '#{payload.inspect}' on listener #{@name}/#{metadata.routing_key}"

        running = @speakers.map { |s| s.object_id }
        callback = proc do |speaker|
          running.delete speaker.object_id
          metadata.ack if ack? && running.empty?
        end

        @speakers.map do |speaker|
          EM.defer nil, callback do
            speaker.parse(metadata, payload)
            speaker
          end
        end
      end
    end
  end
end
