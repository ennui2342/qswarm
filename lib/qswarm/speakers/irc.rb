require 'cinch'
require 'ostruct'

module Qswarm
  module Speakers
    class Irc < Qswarm::Speaker
      @@irc_servers = {}

      def initialize(listener, name, args, &block)        
        @admin_host = args[:admin_host]
        super
      end
      
      def inject(format = :text, msg)
        logger.debug "[#{@agent.name}] Sending '#{msg}' to channel #{@name}"
        publish format, @name, msg
      end

      def run
        @name.match(/([^#]*)(#.+)/) { irc_connect $1.empty? ? 'localhost' : $1, $2 }
      end
            
      def join(m)
        unless m.user.nick == m.bot.nick
          if @admin_host && Regexp.new(@admin_host).match(m.user.host)
            m.channel.op(m.user)
          end
        end
      end

      private
      
      def irc_connect(irc_server, channel)
        if bot = @@irc_servers[irc_server]
          logger.debug "Joining channel #{channel}"
          @@irc_servers[irc_server].config.channels << channel
        else
          logger.debug "Connecting to IRC server #{irc_server} channel #{channel}"
          
          @@irc_servers[irc_server]               = Cinch::Bot.new do
            on :channel do |m|
              if m.message =~ /^#{m.bot.nick}/
                EM.defer do
                  m.bot.config.shared['speaker'].parse( OpenStruct.new( :routing_key => '__', :message => m, :channel => m.channel ), m.message )
                end
              end
            end
            
            on :join do |m|
              m.bot.config.shared['speaker'].join(m)
            end
          end
          
          @@irc_servers[irc_server].config.server = irc_server
          @@irc_servers[irc_server].config.nick   = @agent.name
          @@irc_servers[irc_server].config.channels << channel
          @@irc_servers[irc_server].config.shared['speaker'] = self
          
          EM.defer do
            @@irc_servers[irc_server].start
          end
        end
      end

      def publish(format, name, msg)
        @name.match(/([^#]*)(#.+)/) do
          @@irc_servers[$1.empty? ? 'localhost' : $1].channel_list.find_ensured($2).andand.send(
            format == :json ? JSON.generate(msg) : msg
          )
        end  
      end
        
    end
  end
end