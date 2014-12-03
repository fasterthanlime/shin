
require 'shin/utils/mangler'
require 'set'

module Shin
  module Utils
    module Mimic
      module ClassMethod
        include Shin::Utils::Mangler

        attr_reader :protocols

        def implement(proto, &block)
          @protocols ||= Set.new
          @protocols << "cljs$dcore$v#{proto}"
          block.call if block
        end

        def method_sym(name, arity)
          mangle("#{name}$arity#{arity}").to_sym
        end

        def defn(name, &block)
          sym = self.method_sym(name, block.arity)
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

      def method_sym(name, arity)
        self.class.method_sym(name, arity)
      end

      def invoke(name, *args)
        send(method_sym(name, args.length + 1), *([self].concat(args)))
      end

      def unwrap(node)
        case node
        when Shin::AST::Literal
          node.value
        else
          node
        end
      end

      def pr_str(val)
        _pr_str = method_sym("-pr-str", 1)
        if val.respond_to?(_pr_str)
          val.send(_pr_str, val)
        else
          val.to_s
        end
      end
    end
  end
end

