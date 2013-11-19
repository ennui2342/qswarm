module Qswarm
  class Client
    def initialize(agent, name, args, &block)
      @agent      = agent
      @name       = name
      @args       = args
    end

    def emit(payload)
    end

    def sink(args, payload)
    end

    def format
      @args[:format]
    end

    def run
    end
  end
end
