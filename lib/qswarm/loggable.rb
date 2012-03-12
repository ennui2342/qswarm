require 'logger'
require 'gelf'

module Qswarm
  module Loggable
    def logger
      Loggable.logger
    end

    def self.logger
      # @logger ||= Logger.new(STDOUT)
      @logger ||= GELF::Logger.new($graylog2_host, 12201, 'WAN', { :facility => $greylog2_facility })
    end
  end
end
