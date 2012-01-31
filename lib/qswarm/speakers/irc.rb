require 'cinch'

module Qswarm
  module Speakers
    class IRC < Qswarm::Speaker
      dsl_accessor :irc_server

      def inject(format = :text, msg)
        logger.debug "[#{@agent.name}] Sending '#{msg}' to channel #{@name}"
        publish format, @name, msg
      end

      def run
        logger.debug "Connecting to IRC server #{@irc_server ||= 'localhost'} channel #{@name}"
        
        # This needs fixing. Global vars oh dear
        if $bot
          $bot.config.channels << @name
        else
          $bot = Cinch::Bot.new
          # @bot.config['server'] = @irc_server ||= 'localhost'
          # @bot.config['channels'] = @name.split
          # $bot.config.server = @irc_server ||= 'localhost'
          $bot.config.channels << @name
          $bot.config.nick = @agent.name

          EM.defer do
            $bot.start
          end
        end
      end
      
      private

      def publish(format, channel, msg)
        case format
        when :json
          $bot.channel_manager.find_ensured(channel).andand.send(JSON.generate(msg))
        when :text
          $bot.channel_manager.find_ensured(channel).andand.send(msg)
        end    
      end
    end
  end
end