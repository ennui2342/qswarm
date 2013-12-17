require 'blather/client/dsl'
require 'json'

module Qswarm
  module Connections
    class QBlather
      include Blather::DSL

      Blather.logger.level = Logger::INFO

      def on_connect(block)
        self.instance_eval(&block)
      end
    end

    class Xmpp < Qswarm::Connection
      include Qswarm::DSL

      def initialize(agent, name, args, &block)
        @channels = []
        @connected = false
        @connection = nil
        @on_connect = block_given? ? block : false
        @real_name = args[:real_name] || 'Bot'

        # Use the block for Blather bot DSL
        super(agent, name, args)
      end

      def sink(args, payload)
        if @connected
          # Use channel jid argument from write or from connection itself
          channel = args.nil? || args[:channel].nil? ? @args[:channel] : args[:channel]
          join channel;

          [*channel].each do |c|
            Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Sinking #{payload.raw.inspect} to XMPP channel #{c.inspect}"
            @connection.say c, payload.raw, :groupchat
          end
        else
          EventMachine::Timer.new(5,self.sink(args, payload))
        end
      end

      def run
        xmpp_connect @args[:jid], @args[:password], @args[:channel]
      end

      private

      def join(channel)
        [*channel].each do |c|
          next if @channels.include? c
          Qswarm.logger.debug "Joining XMPP channel #{c}"
          @connection.join c, @real_name
          @channels << c
        end
      end

      def xmpp_connect(jid, password, channel)
        Qswarm.logger.debug "Connecting to XMPP server #{jid}"

        s = QBlather.new
        @connection = s

        s.setup jid, password

        s.when_ready do
          Qswarm.logger.debug "Connected to XMPP server #{jid}"
          @connected = true
          s.on_connect(@on_connect) if @on_connect
          join channel unless channel.nil?
          # Hipchat has a 150s inactivity timer
          EventMachine::PeriodicTimer.new(60) { s << ' ' }
        end

        s.disconnected do
          Qswarm.logger.error "Lost XMPP connection to #{jid}, reconnecting..."
          @connected = false
          @connection.run
        end

        EM.defer do
          s.run
        end
      end

      def status
        "XMPP connected to #{@args[:jid]}, present in channels #{@channel.to_s}"
      end
    end
  end
end
