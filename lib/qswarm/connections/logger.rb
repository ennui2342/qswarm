module Qswarm
  module Connections
    class Logger < Qswarm::Connection
      include Qswarm::DSL

      attr_reader :format

      def initialize(agent, name, args, &block)
        @filename = args[:filename] || '/tmp/qswarm-logger.log'

        super(agent, name, args)
      end

      def emit(payload)
      end

      def sink(args, payload)
        @file.puts payload.raw
      end

      def run
        @file = File.open(@filename, 'a')
        Qswarm.logger.info "[#{@agent.name.inspect} #{@name.inspect}] Logging to #{@filename}"
      end
    end
  end
end
