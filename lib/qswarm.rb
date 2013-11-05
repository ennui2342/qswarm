%w[
  qswarm/version
  qswarm/dsl
  qswarm/swarm
  qswarm/agent
  qswarm/client
  logger
].each { |r| require r }

module Qswarm
  @@logger = nil
  class << self
    def logger
      @@logger ||= Logger.new($stdout).tap {|logger| logger.level = Logger::INFO }
    end
  end
end
