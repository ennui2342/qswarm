require 'tweetstream'
require 'twitter'
require 'json'
require 'ostruct'

module Qswarm
  module Connections
    class Twitter < Qswarm::Connection
      include Qswarm::DSL

      def initialize(agent, name, args, &block)
        TweetStream.configure do |config|
          config.consumer_key = args[:consumer_key]
          config.consumer_secret = args[:consumer_secret]
          config.oauth_token = args[:oauth_token]
          config.oauth_token_secret = args[:oauth_token_secret]
          config.auth_method = :oauth
        end

        @rest_client = ::Twitter::Client.new(
          :consumer_key => args[:consumer_key],
          :consumer_secret => args[:consumer_secret],
          :oauth_token => args[:oauth_token],
          :oauth_token_secret => args[:oauth_token_secret]
        )

        @track = args[:track]
        @follow = args[:follow]
        @list = args[:list]

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
              @track.each do |group, list|
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
                  Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Sending :track/#{group.inspect} #{status.user.screen_name} :: #{status.text} :: #{matches.to_s}"
                  emit(:raw => status.attrs, :headers => { :type => :track, :group => group, :matches => matches })
                end
              end
#            end.on_limit do |skip_count|
#              Qswarm.logger.error "[#{@agent.name.inspect} #{@name.inspect}] There were #{skip_count} tweets missed because of rate limiting."
            end.on_error do |message|
              Qswarm.logger.error "[#{@agent.name.inspect} #{@name.inspect}] #{message}"
            end
          end

          if @follow
            Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Tracking Users: " + @follow.to_s
            TweetStream::Client.new.follow( *@follow.values.flatten ) do |status|
              @follow.each do |group, users|
                if users.include?(status.user.id)
                  Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Sending :follow/#{group.inspect} #{status.user.screen_name} :: #{status.text}"
                  emit(:raw => status.attrs, :headers => { :type => :follow, :group => group, :user_id => status.user.id })
                end
              end
#            end.on_limit do |skip_count|
#              Qswarm.logger.error "[#{@agent.name.inspect} #{@name.inspect}] There were #{skip_count} tweets missed because of rate limiting."
            end.on_error do |message|
              Qswarm.logger.error "[#{@agent.name.inspect} #{@name.inspect}] #{message}"
            end
          end

        rescue TweetStream::ReconnectError
          Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Hit max reconnects, restarting tweetstream in 60 seconds ..."
          EM.timer(60, run)
        end

        if @list
          timer = 30
          since_id = {}

          Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Tracking List: " + @list.to_s + " every #{timer} seconds"

          @list.each do |group, lists|
            lists.each do |user, slug|
              @rest_client.list_timeline(user, slug).each do |status|
                since_id["#{user}/#{slug}"] = status.attrs[:id] and break
              end
            end

            EventMachine::PeriodicTimer.new(timer) do
              lists.each do |user, slug|
                begin
                  @rest_client.list_timeline(user, slug, { :since_id => since_id["#{user}/#{slug}"] }).each do |status|
                    Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Sending :list/#{slug.inspect} #{status.attrs[:user][:screen_name]} :: #{status.text}"
                    emit(:raw => status.attrs, :headers => { :type => :list, :group => group, :user_id => user, :slug => slug })
                    since_id["#{user}/#{slug}"] = status.attrs[:id]
                  end
                rescue ::Twitter::Error::ClientError
                  Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Twitter REST API client error"
                end
              end
            end
          end
        end

        dsl_call(&@on_connect) if @on_connect
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

