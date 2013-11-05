require 'tweetstream'
require 'yajl'
require 'json'
require 'ostruct'

module Qswarm
  module Clients
    class Twitter < Qswarm::Client
      def initialize(agent, name, args, &block)
        TweetStream.configure do |config|
          config.consumer_key = args[:consumer_key]
          config.consumer_secret = args[:consumer_secret]
          config.oauth_token = args[:oauth_token]
          config.oauth_token_secret = args[:oauth_token_secret]
          config.auth_method = :oauth
          config.parser   = :yajl
        end

        @track = args[:track]
        @follow = args[:follow]

        super
      end

      def emit(payload)
        @agent.emit(@name, :payload => OpenStruct.new(payload))
      end

      def sink(metadata, payload)
        Qswarm.logger.info ">>> #{payload}"
      end

      def status
        "Connected to tweetstream, tracking #{@track.to_s}, following #{@follow.to_s}"
      end

      def run
        begin
          if @track
            Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Tracking keywords: " + @track.to_s
            TweetStream::Client.new.track( @track.values.flatten.reject { |k| /^-/.match(k) } ) do |status|
              @track.each do |topic, list|
                matches = []
                list.each do |keyword|
                  # Text doesn't include any words in the phrase prefixed with -
                  if keyword.split(' ').select { |k| /^-/.match(k) }.none? { |word| status.text.downcase.include? word[1..-1].downcase }
                    # Text contains all of the words in the phrase
                    if keyword.split(' ').reject { |k| /^-/.match(k) }.all? { |word| status.text.downcase.include? word.downcase }
                      matches << keyword
                    end
                  end
                end

                if !matches.empty?
                  Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Sending :track/#{topic.inspect} #{status.user.screen_name} :: #{status.text} :: #{matches.to_s}"
                  emit(:raw => status.attrs, :type => :track, :topic => topic, :matches => matches, :text => status.text)
                end
              end
            end
          end

          if @follow
            Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Tracking Users: " + @follow.to_s
            TweetStream::Client.new.follow( *@follow.values.flatten ) do |status|
              @follow.each do |group, users|
                if users.include?(status.user.id)
                  Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Sending :follow/#{group.inspect} #{status.user.screen_name} :: #{status.text}"
                  emit(:raw => status.attrs, :type => :follow, :group => group, :user_id => status.user.id, :text => status.text)
                end
              end
            end
          end
        end

        rescue TweetStream::ReconnectError
          Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Hit max reconnects, restarting tweetstream in 60 seconds ..."
          EM.timer(60, run)
        end
      end
  end
end

__END__

            end.on_reconnect do |timeout, retries|
#            puts "RECONNECT #{retries}"
            end
          c.on_error do |message|
            puts "ERROR #{message}"
          end
#  client.on_delete do |status_id, user_id|
#    puts "DELETE #{status_id}"
#  end

end

#  c.on_limit do |skip_count|
#    puts "RATE LIMIT"
#  end

