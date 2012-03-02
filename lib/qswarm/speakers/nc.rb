module Qswarm
  module Speakers
    class Nc < Qswarm::Speaker
      @@connections = {}

      def inject(format = :text, msg)
        publish format, msg
      end

      def run
        @name.match(/([^#]*):(\d+)/) do
          @host = $1.empty? ? 'localhost' : $1
          @port = $2
          @server = @host + ':' + @port
          # @service = $3
        end
        connect
      end

      private

      def connect
        if connection = @@connections[@server]
          logger.debug "Connecting to service #{@service}"
        else
          logger.debug "Connecting to host #{@server} service #{@service}"
          @@connections[@server] = EventMachine::connect @host, @port do |connection|
            def connection.receive_data(data)
              puts "Received #{data} from #{@name}"
            end
          end
        end
      end

      def publish(format, msg)
        logger.debug "Sending '#{msg}' to #{@name}"
        @@connections[@server].send_data( (format == :json ? JSON.generate(msg) : msg) + "\n")
      end
    end
  end
end
