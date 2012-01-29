require 'eventmachine'
require 'amqp'
require 'cgi'

require 'qswarm/dsl'

module Qswarm
  class Broker
    include Qswarm::Loggable
    extend Qswarm::DSL

    dsl_accessor :name, :host, :port, :user, :pass, :vhost, :exchange_type, :exchange_name, :durable, :prefetch
    @@connection = {}

    def initialize(name, &block)
      @name          = name

      # Set some defaults
      @host          = 'localhost'
      @port          = 5672
      @user          = 'guest'
      @pass          = 'guest'
      @vhost         = ''
      @exchange_type = :direct
      @exchange_name = ''
      @durable       = true
      @prefetch      = nil

      self.instance_eval(&block)

      @queues        = {}
      @channels      = {}
      @exchange      = nil

      Signal.trap("INT") do
        @@connection["#{@host}:#{@port}#{@vhost}"].close do
          EM.stop { exit }
        end
      end
    end

    def queue name, routing_key = '', args = nil
      @queues["#{name}/#{routing_key}"] ||= begin
        logger.debug "Binding queue #{name}/#{routing_key}"
        @queues["#{name}/#{routing_key}"] = channel(name, routing_key).queue(name, args).bind(exchange(channel(name, routing_key)), :routing_key => routing_key)
      end
    end

    def exchange(channel = nil)
      @exchange ||= begin
        @exchange = AMQP::Exchange.new(channel ||= AMQP::Channel.new(connection), @exchange_type, @exchange_name, :durable => @durable) do |exchange|
          logger.debug "Declared #{@exchange_type} exchange #{@vhost}/#{@exchange_name}"
        end
      end
    end

    # ruby-amqp currently limits to 1 consumer per queue (to be fixed in future) so can't pool channels
    def channel name, routing_key = ''
      @channels["#{name}/#{routing_key}"] ||= begin
        logger.debug "Opening channel for #{name}/#{routing_key}"
        @channels["#{name}/#{routing_key}"] = AMQP::Channel.new(connection, :prefetch => @prefetch)
      end
    end

    def connection
      # Pool connections at the class level
      @@connection["#{@host}:#{@port}#{@vhost}"] ||= begin
        logger.debug "Connecting to AMQP broker at #{@host}:#{@port}#{@vhost}"
        @@connection["#{@host}:#{@port}#{@vhost}"] = AMQP.connect("amqp://#{@user}:#{@pass}@#{@host}:#{@port}/#{CGI.escape(@vhost)}")
      end
    end

    def to_s
      "amqp://#{@user}:#{@pass}@#{@host}:#{@port}/#{CGI.escape(@vhost)}"
    end
  end
end