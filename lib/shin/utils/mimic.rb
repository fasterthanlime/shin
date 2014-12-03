
require 'shin/utils/mangler'
require 'set'

module Shin
  module Utils
    module Mimic
      include Shin::Utils::Mangler

      module ClassMethod
        include Shin::Utils::Mangler

        attr_reader :protocols

        def implement(proto, &block)
          @protocols ||= Set.new
          @protocols << "cljs$dcore$v#{proto}"
          block.call if block
        end

        def defn(name, &block)
          sym = mangle("#{name}$arity#{block.arity}").to_sym
          define_method(sym, &block)
        end
      end

      def self.included(base)
        base.extend(ClassMethod)
      end

      def [](x)
        return true if self.class.protocols.include?(x)
        puts "[#{self.class.name}] does not implement Clojure protocol #{x}"
        nil
      end

      def invoke(name, *args)
        sym = mangle("#{name}$arity#{args.length + 1}").to_sym
        send(sym, *([self].concat(args)))
      end

      def unwrap(node)
        case node
        when Shin::AST::Literal
          node.value
        else
          node
        end
      end
    end
  end
end

