# require 'mysql2'

module Qswarm
  module Speakers
    class Mysql < Qswarm::Speaker
      @@db_servers = {}

      def inject(format = :text, msg)
        logger.debug "[#{@agent.name}] Sending '#{msg}' to channel #{@name}"
        publish format, @name, msg
      end

      def run
        @name.match(/([^#]*)(#.+)/) { db_connect $1.empty? ? 'localhost' : $1, $2 }
      end

      private

      def db_connect(db_server, database)
        if connection = @@db_servers[db_server]
          logger.debug "Connecting to database #{database}"
        else
          logger.debug "Connecting to DB server #{db_server} database #{database}"
          @@db_servers[db_server]               = 'foo'
        end
      end

      def publish(format, name, msg)
        @name.match(/([^#]*)(#.+)/) do
          logger.debug "#{$1} #{$2} #{msg}"
          # @@db_servers[$1.empty? ? 'localhost' : $1].channel_manager.find_ensured($2).andand.send(
          #    format == :json ? JSON.generate(msg) : msg
          #  )
          #         end  
        end
      end
    end
  end
end