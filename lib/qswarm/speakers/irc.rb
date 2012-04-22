require 'cinch'
require 'ostruct'

module Qswarm
  module Speakers
    class Irc < Qswarm::Speaker
      @@irc_servers = {}

      def initialize(listener, name, args, &block)        
        @admin_host = args[:admin_host]
        @channels = []
        @connected = false
        super
      end
      
      def inject(format = :text, msg)
        if @connected
          routing_key = @bind || @name
          logger.debug "[#{@agent.name}] Sending '#{msg}' to channel #{routing_key}"
          publish format, routing_key, msg
        else
          EventMachine::Timer.new(5,self.inject(format, msg))
        end
      end

      def run
        @name.match(/([^#]*)(#.+)/) { irc_connect $1.empty? ? 'localhost' : $1, $2 }
      end
            
      def on_join(m)
        unless m.user.nick == m.bot.nick
          if @admin_host && Regexp.new(@admin_host).match(m.user.host)
            m.channel.op(m.user)
          end
        end
      end
      
      def on_connect(m)
        @connected = true
      end
      
      def on_disconnect(m)
        @connected = false
      end

      private

      def join(irc_server, channel)
        if !@channels.include? channel
          logger.debug "Joining channel #{channel}"
          @@irc_servers[irc_server].channel_list.find_ensured(channel).join()
          @channels << channel
        end
      end
      
      def irc_connect(irc_server, channel)
        if bot = @@irc_servers[irc_server]
          join irc_server, channel
        else
          logger.debug "Connecting to IRC server #{irc_server} channel #{channel}"
          
          @@irc_servers[irc_server] = Cinch::Bot.new do
            on :channel do |m|
              if m.message =~ /^#{m.bot.nick}/
                EM.defer do
                  m.bot.config.shared['speaker'].parse( OpenStruct.new( :routing_key => '__', :message => m, :channel => m.channel ), m.message )
                end
              end
            end
            
            on :join do |m|
              m.bot.config.shared['speaker'].on_join(m)
            end
            
            on :connect do |m|
              m.bot.config.shared['speaker'].on_connect(m)
            end
            
            on :disconnect do |m|
              m.bot.config.shared['speaker'].on_disconnect(m)
            end
          end
          
          @@irc_servers[irc_server].config.server = irc_server
          @@irc_servers[irc_server].config.nick   = @agent.name
          @@irc_servers[irc_server].config.channels << channel
          @@irc_servers[irc_server].config.shared['speaker'] = self

          @channels << channel
          
          EM.defer do
            @@irc_servers[irc_server].start
          end
        end
      end

      def publish(format, name, msg)
        name.match(/([^#]*)(#.+)/) do
          irc_server = $1.empty? ? 'localhost' : $1
          join(irc_server, $2)
          @@irc_servers[irc_server].channel_list.find($2).andand.send( format == :json ? JSON.generate(msg) : msg )
        end  
      end
        
    end
  end
end
