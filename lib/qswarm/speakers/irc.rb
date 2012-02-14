require 'cinch'

module Qswarm
  module Speakers
    class Irc < Qswarm::Speaker
      @@irc_servers = {}
        
      def inject(format = :text, msg)
        logger.debug "[#{@agent.name}] Sending '#{msg}' to channel #{@name}"
        publish format, @name, msg
      end

      def run
        @name.match(/([^#]*)(#.+)/) { irc_connect $1.empty? ? 'localhost' : $1, $2 }
      end
      
      private
      
      def irc_connect(irc_server, channel)
        if bot = @@irc_servers[irc_server]
          logger.debug "Joining channel #{channel}"
          @@irc_servers[irc_server].config.channels << channel
        else
          logger.debug "Connecting to IRC server #{irc_server} channel #{channel}"
          @@irc_servers[irc_server]               = Cinch::Bot.new
          @@irc_servers[irc_server].config.server = irc_server
          @@irc_servers[irc_server].config.nick   = @agent.name
          @@irc_servers[irc_server].config.channels << channel
          
          EM.defer do
            @@irc_servers[irc_server].start
          end
        end
      end

      def publish(format, name, msg)
        @name.match(/([^#]*)(#.+)/) do
          @@irc_servers[$1.empty? ? 'localhost' : $1].channel_manager.find_ensured($2).andand.send(
            format == :json ? JSON.generate(msg) : msg
          )
        end  
      end
    end
  end
end