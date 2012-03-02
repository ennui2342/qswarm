require 'uri'
require 'em-http-request'

module Qswarm
  module Speakers
    class Http < Qswarm::Speaker
      @@connections = {}

      def initialize(listener, name, &block)
        @uri = URI.parse(name)
        @uri.host = 'localhost' if @uri.host.nil?
        super
      end

      def inject(format = :text, msg)
        publish format, msg
      end

      def run
        connect
      end

      private

      def connect
      end

      def publish(format, msg)
        logger.debug "Sending '#{msg}' to #{@name}"
        
        case format
        when :get
          if msg.is_a? Hash
            http = EventMachine::HttpRequest.new(@uri).get :query => msg
          else
            http = EventMachine::HttpRequest.new(URI.join(@uri.to_s, msg)).get
          end
          http.errback do |err|
            logger.error "Error sending #{msg} to #{@name}: #{err}"
          end
          http.callback do 
            logger.debug "#{http.response_header.status} #{http.response}"
          end
        end
      end
    end
  end
end