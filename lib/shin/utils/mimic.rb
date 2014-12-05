
require 'shin/utils/mangler'
require 'set'

module Shin
  module Utils
    module Mimic
      DEBUG = ENV['MIMIC_DEBUG']

      module ClassMethod
        include Shin::Utils::Mangler

        def core_proto_name(proto)
          "cljs$dcore$v#{proto}"
        end

        def implement(proto, &block)
          name = core_proto_name(proto)
          define_method(name) { true }

          if proto == :IFn
            # IFn is special, cf. #50
            define_method(:call) do |*args|
              sym = method_sym('-invoke', args.length)
              send(sym, *args)
            end
          end

          block.call if block
        end

        def method_sym(name, arity)
          mangle("#{name}$arity#{arity}")
        end

        def defn(name, &block)
          sym = self.method_sym(name, block.arity)
          define_method(sym, &block)
        end
      end

      def self.included(base)
        base.extend(ClassMethod)
      end

      def method_sym(name, arity)
        self.class.method_sym(name, arity)
      end

      def core_proto_name(name)
        self.class.core_proto_name(name)
      end

      def js_invoke(val, name, *args)
        name = method_sym(name, args.length + 1)
        f = val[name]
        if f
          f.methodcall(val, val, *args)
        else
          raise "Can't invoke #{name} on JS object #{val}"
        end
      end

      # AST nodes -> ClojureScript data structures
      def unwrap(node)
        if node.literal?
          node.value
        else
          node
        end
      end

      # ClojureScript data structures -> AST nodes
      def wrap(val)
        case val
        when Shin::AST::Node
          node
        when Fixnum, Float, String
          # using our token.. better than muffin!
          Shin::AST::Literal.new(token, val)
        when V8::Object
          type = v8_type(val)
          case type
          when :keyword
            name = js_invoke(val, "-name")
            Shin::AST::Keyword.new(Token.dummy, name)
          when :symbol
            name = js_invoke(val, "-name")
            Shin::AST::Symbol.new(Token.dummy, name)
          else
            raise "Unknown V8 type: #{type}"
          end
        else
          raise "Not sure how to wrap: #{val} of type #{val.class.name}"
        end
      end

      @@identity_cache = {}

      def v8_type(val)
        val.instance_variable_get(:@context).enter do
          vn = val.native
          hash = vn.Get('constructor').GetIdentityHash
          @@identity_cache[hash] ||= sniff_v8type(vn)
        end
      end

      def sniff_v8type(vn)
        case true
        when vn.Get(core_proto_name("IVector"))  then :vector
        when vn.Get(core_proto_name("ISeq"))     then :list
        when vn.Get(core_proto_name("ISymbol"))  then :symbol
        when vn.Get(core_proto_name("IKeyword")) then :keyword
        when vn.Get(core_proto_name("IMap"))     then :map
        when vn.Get(core_proto_name("IUnquote")) then :unquote
        else :unknown
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

