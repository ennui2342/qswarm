require 'uri'
require 'em-http-request'

module Qswarm
  module Speakers
    class Http < Qswarm::Speaker
      @@connections = {}

      def initialize(listener, name, args, &block)
        @uri = URI.parse(name)
        @uri.host = 'localhost' if @uri.host.nil?
        super
      end

      def inject(format = :text, msg)
        publish format, msg
      end

      def run
      end

      private
      
      def auth?
        
      end

      def publish(format, msg)
        logger.debug "Sending '#{msg}' to #{@name}"
        head = @args.user.nil? ? {} : { 'authorization' => [@args.user, @args.password] }
        
        case format
        when :get
          if msg.is_a? Hash
            http = EventMachine::HttpRequest.new(@uri).get :head => head, :query => msg
          else
            http = EventMachine::HttpRequest.new(URI.join(@uri.to_s, msg)).get :head => head
          end
          http.errback do
            logger.error "Error sending #{msg} to #{@name}: #{http.error}/#{http.response}"
          end
          http.callback do 
            if @args.expect != http.response_header.status
              logger.error "#{@uri.to_s} Unexpected response code: #{http.response_header.status} #{http.response}"
            end
          end
        
        when :post
          http = EventMachine::HttpRequest.new(@uri).post :head => head, :body => msg
          http.errback do |err|
            logger.error "Error sending #{msg} to #{@name}: #{err}"
          end
          http.callback do 
            if @args.expect != http.response_header.status
              logger.error "#{@uri.to_s} Unexpected response code: #{http.response_header.status} #{http.response}"
            end
          end
        end
      end
    end
  end
end
