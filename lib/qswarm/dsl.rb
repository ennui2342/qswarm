module Qswarm
  module DSL
    module Config
      @@caller = nil

      def self.caller
        @@caller
      end

      def self.caller=(caller)
        @@caller = caller
      end

      class Swarm; extend Qswarm::DSL::Config; end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def dsl_load(config)
      dsl_call(File.read(config))
    end

    def dsl_call(string = nil, &block)
      parent = Config.caller
      Config.caller = self
      if string.nil?
        res = Config::Swarm.module_eval(&block)
      else
        res = Config::Swarm.module_eval(string)
      end
      Config.caller = parent
      res
    end

    module ClassMethods
      def dsl_accessor(*symbols)
        symbols.each do |sym|
          Qswarm::DSL::Config.module_eval %{
            def #{sym}
              @@#{sym}
            end

            def #{sym}=(*val)
              @@#{sym} = val.size == 1 ? val[0] : val
            end
          }
        end
      end

      def dsl(*symbols)
        symbols.each do |sym|
          Qswarm::DSL::Config.module_eval "def #{sym}(*args, &block) @@caller.send(#{sym.inspect}, *args, &block); end"
          #Qswarm::DSL::Config.module_eval "def #{sym}(name, args = nil, &block) @@caller.send(#{sym.inspect}, name, args, &block); end"
          #Qswarm::DSL::Config.module_eval { define_method(sym, -> (name, args = nil, &block) { @@caller.send(sym.inspect, name, args, &block) } ) }
        end
      end
    end
  end
end
