module Qswarm
  class Connection
    attr_reader :format

    def initialize(agent, name, args, &block)
      @agent      = agent
      @name       = name
      @args       = args
      @on_connect = block_given? ? block : false

      @format     = args[:format] || :raw
    end

    def emit(payload)
      @agent.emit(@name, :payload => OpenStruct.new(:raw => payload, :format => @format))
    end

    def sink(args, payload)
      Qswarm.logger.info ">>> #{payload.raw}"
    end

    def run
    end
  end
end
