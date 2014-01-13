require 'amqp'
require 'cgi'
require 'uuid'
require 'json'
require 'ostruct'

module Qswarm
  module Connections
    class Amqp < Qswarm::Connection
      include Qswarm::DSL

#    dsl_accessor :name, :host, :port, :user, :pass, :vhost, :exchange_type, :exchange_name, :durable
      @@connection = {}

      def initialize(agent, name, args, &block)
        # Set some defaults
        @protocol      = 'amqp'
        @host          = 'localhost'
        @port          = 5672
        @user          = 'guest'
        @pass          = 'guest'
        @vhost         = ''
        @durable       = true
        @prefetch      = args[:prefetch] || 0

        decode_uri(args[:uri]) if args[:uri]

        @queues        = {}
        @channels      = {}
        @exchange      = nil
        @instances     = nil

        @queue_args     = { :auto_delete => true, :durable => true, :exclusive => true }.merge! args[:queue_args] || {}
        @subscribe_args = { :exclusive => false, :ack => false }.merge! args[:subscribe_args] || {}
        @bind_args      = args[:bind_args] || {}
        @exchange_type  = args[:exchange_type] || :direct
        @exchange_name  = args[:exchange_name] || ''
        @exchange_args  = { :durable => true }.merge! args[:exchange_args] || {}
        @uuid           = UUID.generate if args[:uniq]
        @bind           = args[:bind]

        Signal.trap("INT") do
          @@connection["#{@host}:#{@port}/#{@vhost}"].close do
            EM.stop { exit }
          end
        end

        super
      end

      def queue(name, routing_key = '', args = nil)
        @queues["#{name}/#{routing_key}"] ||= begin
          Qswarm.logger.debug "Binding queue #{name}/#{routing_key}"
          @queues["#{name}/#{routing_key}"] = channel(name, routing_key).queue(name, args).bind(exchange(channel(name, routing_key)), @bind_args.merge(:routing_key => routing_key))
        end
      end

      def exchange(channel = nil)
        @exchange ||= begin
          @exchange = AMQP::Exchange.new(channel ||= AMQP::Channel.new(connection, :auto_recovery => true), @exchange_type, @exchange_name, @exchange_args) do |exchange|
            Qswarm.logger.debug "Declared #{@exchange_type} exchange #{@vhost}/#{@exchange_name}"
            exchange.on_return do |basic_return, metadata, payload|
              Qswarm.logger.error "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
            end
          end
        end
      end

      # ruby-amqp currently limits to 1 consumer per queue (to be fixed in future) so can't pool channels
      def channel(name, routing_key = '')
        @channels["#{name}/#{routing_key}"] ||= begin
          Qswarm.logger.debug "Opening channel for #{name}/#{routing_key}"
          @channels["#{name}/#{routing_key}"] = AMQP::Channel.new(connection, AMQP::Channel.next_channel_id, :auto_recovery => true, :prefetch => @prefetch) do |c|
            @channels["#{name}/#{routing_key}"].on_error do |channel, channel_close|
              Qswarm.logger.error "[channel.close] Reply code = #{channel_close.reply_code}, reply text = #{channel_close.reply_text}"
            end
          end
        end
      end

      def connection
        # Pool connections at the class level
        @@connection["#{@host}:#{@port}/#{@vhost}"] ||= begin
          Qswarm.logger.debug "Connecting to AMQP broker #{self.to_s}"
          @@connection["#{@host}:#{@port}/#{@vhost}"] = AMQP.connect(self.to_s, :heartbeat => 30, :on_tcp_connection_failure => Proc.new { |settings|
              Qswarm.logger.error "AMQP initial connection failure to #{settings[:host]}:#{settings[:port]}/#{settings[:vhost]}"
              EM.stop
            }, :on_possible_authentication_failure => Proc.new { |settings|
              Qswarm.logger.error "AMQP initial authentication failed for #{settings[:host]}:#{settings[:port]}/#{settings[:vhost]}"
              EM.stop
            }
          ) do |c|
            @@connection["#{@host}:#{@port}/#{@vhost}"].on_recovery do |connection|
              Qswarm.logger.debug "Recovered from AMQP network failure"
            end
            @@connection["#{@host}:#{@port}/#{@vhost}"].on_tcp_connection_loss do |connection|
              # reconnect in 10 seconds
              Qswarm.logger.error "AMQP TCP connection lost, reconnecting in 2s"
              connection.periodically_reconnect(2)
            end
            @@connection["#{@host}:#{@port}/#{@vhost}"].on_connection_interruption do |connection|
              Qswarm.logger.error "AMQP connection interruption"
            end
            # Force reconnect on heartbeat loss to cope with our funny firewall issues
            @@connection["#{@host}:#{@port}/#{@vhost}"].on_skipped_heartbeats do |connection, settings|
              Qswarm.logger.error "Skipped heartbeats detected"
            end
            @@connection["#{@host}:#{@port}/#{@vhost}"].on_error do |connection, connection_close|
              Qswarm.logger.error "AMQP connection has been closed. Reply code = #{connection_close.reply_code}, reply text = #{connection_close.reply_text}"
              if connection_close.reply_code == 320
                Qswarm.logger.error "Set a 30s reconnection timer"
                # every 30 seconds
                connection.periodically_reconnect(30)
              end
            end
            Qswarm.logger.debug "Connected to AMQP broker #{self.to_s}"
          end
        end
      end

      def decode_uri(uri)
        if uri.match(/(amqp.?):\/\/(.*)/)
          @protocol = $1
          uri = $2
        else
          @protocol = 'amqp'
        end
        @user, @pass, @host, @port, @vhost = uri.match(/([^:]+):([^@]+)@([^:]+):([^\/]+)\/(.*)/).captures
      end

      def ack?
        @subscribe_args[:ack]
      end

      def to_s
        "#{@protocol}://#{@user}:#{CGI.escape(@pass)}@#{@host}:#{@port}/#{CGI.escape('/' + @vhost)}"
      end

      def status
        "AMQP connection #{@name.inspect} at #{@args[:uri]}, bound to #{@args[:bind]}/#{@args[:bind_args]} on #{@args[:exchange_type].inspect} exchange #{@args[:exchange_name]}"
      end

      def run
        if !@bind.nil?
          [*@bind].each do |bind|
            queue(@agent.name.to_s + '.' +  @name.to_s + @uuid ||= '', bind, @queue_args).subscribe(@subscribe_args) do |metadata, payload|
              emit metadata, payload
            end
          end

          dsl_call(&@on_connect) if @on_connect
        end
      end

      def emit(metadata, payload)
        Qswarm.logger.info "[#{@agent.name.inspect}] :amqp connection #{@name.inspect} bound to #{metadata.routing_key}, received #{payload.inspect}"

        @agent.emit(@name, :payload => OpenStruct.new(:raw => payload, :headers => (metadata.headers.nil? ? {} : Hash[metadata.headers.map{ |k, v| [k.to_sym, v] }]).merge(:routing_key => metadata.routing_key), :format => @format))
        metadata.ack if ack?
      end

      def sink(args, payload)
        [*args[:routing_key]].each do |routing_key|
          Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Sinking #{payload.raw.inspect} to AMQP routing_key #{routing_key.inspect}"
          if args[:headers] || payload.headers
            exchange.publish payload.raw, :routing_key => routing_key, :headers => (args[:headers] ? args[:headers] : payload.headers).merge(:routing_key => routing_key)
          else
            exchange.publish payload.raw, :routing_key => routing_key
          end
        end
      end
    end
  end
end
