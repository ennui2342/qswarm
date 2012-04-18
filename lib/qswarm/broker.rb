require 'eventmachine'
require 'amqp'
require 'cgi'

require 'qswarm/dsl'

module Qswarm
  class Broker
    include Qswarm::Loggable
    extend Qswarm::DSL

    dsl_accessor :name, :host, :port, :user, :pass, :vhost, :exchange_type, :exchange_name, :durable
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

      # if block.arity == 1
      #    yield self
      #  else
      #    instance_eval &block
      #  end

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
          @exchange.on_return do |basic_return, metadata, payload|
            logger.error "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
          end
        end
      end
    end

    # ruby-amqp currently limits to 1 consumer per queue (to be fixed in future) so can't pool channels
    def channel name, routing_key = ''
      @channels["#{name}/#{routing_key}"] ||= begin
        logger.debug "Opening channel for #{name}/#{routing_key}"
        @channels["#{name}/#{routing_key}"] = AMQP::Channel.new(connection, AMQP::Channel.next_channel_id, :auto_recovery => true) do |c|
          @channels["#{name}/#{routing_key}"].on_error do |channel, channel_close|
            logger.error "[channel.close] Reply code = #{channel_close.reply_code}, reply text = #{channel_close.reply_text}"
          end
        end
      end
    end

    def connection
      # Pool connections at the class level
      @@connection["#{@host}:#{@port}#{@vhost}"] ||= begin
        logger.debug "Connecting to AMQP broker at #{self.to_s}"
        @@connection["#{@host}:#{@port}#{@vhost}"] = AMQP.connect(self.to_s, :heartbeat => 30, :on_tcp_connection_failure => Proc.new { |settings|
            logger.error "AMQP initial connection failure to #{settings[:host]}:#{settings[:port]}#{settings[:vhost]}"
            EM.stop
          }, :on_possible_authentication_failure => Proc.new { |settings|
            logger.error "AMQP initial authentication failed for #{settings[:host]}:#{settings[:port]}#{settings[:vhost]}"
            EM.stop
          }
        ) do |c|
          @@connection["#{@host}:#{@port}#{@vhost}"].on_recovery do |connection|
            logger.debug "Recovered from AMQP network failure"
          end
          @@connection["#{@host}:#{@port}#{@vhost}"].on_connection_interruption do |connection|
            # reconnect in 10 seconds, without enforcement
            logger.error "AMQP connection interruption, reconnecting in 10s"
            connection.reconnect(false, 10)
          end
          # Force reconnect on heartbeat loss to cope with our funny firewall issues
          @@connection["#{@host}:#{@port}#{@vhost}"].on_skipped_heartbeats do |connection, settings|
            logger.error "Skipped heartbeats detected, reconnecting in 10s"
            connection.reconnect(false, 10)
          end
          # @@connection["#{@host}:#{@port}#{@vhost}"].on_connection_interruption do |connection|
          #   logger.error "Connection detected connection interruption"
          # end
          @@connection["#{@host}:#{@port}#{@vhost}"].on_error do |connection, connection_close|
            logger.error "AMQP connection has been closed. Reply code = #{connection_close.reply_code}, reply text = #{connection_close.reply_text}"
            if connection_close.reply_code == 320
              logger.error "Set a 30s reconnection timer"
              # every 30 seconds
              connection.periodically_reconnect(30)
            end
          end
        end
      end
    end

    def to_s
      "amqp://#{@user}:#{@pass}@#{@host}:#{@port}/#{CGI.escape(@vhost)}"
    end
  end
end
