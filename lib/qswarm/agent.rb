require 'ostruct'
require 'json'
require 'nokogiri'

module Qswarm
  class Agent
    include Qswarm::DSL

    attr_reader :swarm, :name
    dsl :connect, :before, :after, :source, :sink, :emit, :payload

    def initialize(swarm, name, args = nil, &block)
      @swarm              = swarm
      @name               = name
      @clients            = {}
      @args               = args
      @filters            = {}
      @handlers           = {}
      @payload            = nil

      dsl_call(&block)
    end

    def payload
      @payload
    end

    # Connects to a data stream
    #
    # @param name [String] the name of the connection
    # @param args [Hash] arguments for the connection
    # @param &block [Proc] a block which is passed to the client constructor
    def connect(name, args = nil, &block)
      raise "Connection '#{name.inspect}' is a reserved name" if %i[echo xmpp irc amqp].include? name
      raise "Connection '#{name.inspect}' is already registered" if @clients[name]

      if !args.nil? && !args[:type].nil?
        Qswarm.logger.info "[#{@name.inspect}] Registering #{args[:type].inspect} connection #{name.inspect}"
        require "qswarm/clients/#{args[:type].downcase}"
        @clients[name] = eval("Qswarm::Clients::#{args[:type].capitalize}").new(self, name, args, &block)
      else
        Qswarm.logger.info "[#{@name.inspect}] Registering default connection #{name.inspect}"
        @clients[name] = Qswarm::Client.new(self, name, args, &block)
      end
    end

    def before(connection, *guards, &block)
      Qswarm.logger.info "[#{@name.inspect}] Registering :before filter for #{connection.inspect}/#{guards.inspect}"

      case connection
      when Symbol
        register_filter :before, connection, *guards, &block

      when Array
        connection.each do |c|
          register_filter :before, c, *guards, &block
        end
      end
    end

    def after(connection, *guards, &block)
      Qswarm.logger.info "[#{@name.inspect}] Registering :after filter for #{connection.inspect}/#{guards.inspect}"

      case connection
      when Symbol
        register_filter :after, connection, *guards, &block

      when Array
        connection.each do |c|
          register_filter :after, c, *guards, &block
        end
      end
    end

    def source(connection, *guards, &block)
      Qswarm.logger.info "[#{@name.inspect}] Registering handler for #{connection.inspect}/#{guards.inspect}"

      case connection
      when Symbol
        register_handler connection, *guards, &block

      when Array
        connection.each do |c|
          register_handler c, *guards, &block
        end
      end
    end

    def sink(connection, args = nil, &block)
      Qswarm.logger.debug "[#{@name.inspect}] Sink #{connection.inspect} received #{@payload.inspect}"

      # Payload from DSL parent context overidden by arguments and block locally to sink
      p = @payload.dup
      p.data = args[:data] unless args.nil? || args[:data].nil?
      p.data = dsl_call(&block) if block_given?

      # Update raw from the current data
      p.raw = case args[:format]
              when :json
                JSON.generate(p.data)
              when :xml
                p.data.to_xml
              else # raw
                p.data
              end unless args.nil?

      case connection
      when Symbol
        @clients[connection].sink(args, p)

      when Array
        connection.each do |c|
          @clients[c].sink(args, p)
        end
      end
    end

    def emit(connection, args = nil, &block)
      # Need to set @payload for access by the dsl_call when handlers are run
      # Overwriting global parent this will break when nesting emit in source which will loose the payload originating from connection
      @payload = args[:payload] unless args.nil? || args[:payload].nil?
      @payload = dsl_call(&block) if block_given?

      Qswarm.logger.debug "[#{@name.inspect}] Connection #{connection.inspect} emitting #{@payload.inspect}"

      @payload.data = case payload.format
                      when :json
                        JSON.parse(@payload.raw)
                      when :xml
                        Nokogiri::XML(@payload.raw)
                      else # :raw
                       @payload.raw
                      end

      case connection
      when Symbol
        run_filters :before, connection
        call_handlers connection
        run_filters :after, connection

      when Array
        connection.each do |c|
          run_filters :before, c
          call_handlers c
          run_filters :after, c
        end
      end
    end

    def run
      @clients.each { |name, client| client.run }
    end

    private

    def run_filters(type, connection)
      return if @filters[type].nil?
      @filters[type].each do |guards, client, block|
        next if client != connection
        dsl_call(&block) unless guarded?(guards, @payload)
      end
    end

    def call_handlers(connection)
      return if !handlers = @handlers[connection]
      handlers.each do |guards, block|
        if !guarded?(guards, @payload)
          Qswarm.logger.debug "[#{@name.inspect}] Source #{connection.inspect} received #{@payload.inspect}"
          dsl_call(&block)
        end
      end
    end

    def register_filter(type, client, *guards, &block)
      raise "Invalid filter: #{type}. Must be :before or :after" unless [:before, :after].include? type
      @filters[type] ||= []
      @filters[type] << [guards, client, block]
    end

    def register_handler(client, *guards, &block)
      @handlers[client] ||= []
      @handlers[client] << [guards, block]
    end

    def guarded?(guards, data)
      return false if guards.nil? || guards.empty?
      guards.find do |guard|
        case guard
        when Symbol
          !data.__send__(guard)
        when Array
          # return FALSE if any item is TRUE
          !guard.detect { |condition| !guarded?([condition], data) }
        when Hash
          # return FALSE unless any inequality is found
          guard.find do |method, test|
            value = data.__send__(method)
            # last_match is the only method found unique to Regexp classes
            if test.class.respond_to?(:last_match)
              !(test =~ value.to_s)
            elsif test.is_a?(Array)
              !test.include? value
            else
              test != value
            end
          end
        when Proc
          !guard.call(data)
        end
      end
    end

  end
end
