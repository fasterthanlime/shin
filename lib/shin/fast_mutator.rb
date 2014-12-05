
require 'shin/utils/mangler'

module Shin
  class FastMutator
    include Shin::Utils::Mangler
    include Shin::Utils::Mimic

    DEBUG = ENV['FAST_MUTATOR_DEBUG']

    attr_reader :context
    @@total_prep = 0
    @@total_call = 0
    @@total_deserialize = 0
    @@total_nsp = 0      
    @@total_mut = 0    
    @@total_trn = 0
    @@total_gen = 0

    def initialize(compiler, mod, context)
      @compiler = compiler
      @mod = mod
      @expands = 0
      @context = context
      @v8 = @context.context
    end

    def expand(invoc, info)
      macro_gifted_args = nil
      macro_func = nil
      macro_slug = nil

      @@total_prep += Benchmark.realtime do
        debug "==============================================="

        deps = @compiler.collect_deps(info[:module])
        all_in_cache = deps.keys.all? { |slug| @compiler.modules.include?(slug) }
        unless all_in_cache
          raise "Not all deps in cache: #{deps.keys}"
        end

        deps.each do |slug, dep|
          @@total_nsp += Benchmark.realtime { Shin::NsParser.new(dep).parse unless dep.ns }
          @@total_mut += Benchmark.realtime { Shin::Mutator.new(@compiler, dep).mutate unless dep.ast2 }
          @@total_trn += Benchmark.realtime { Shin::Translator.new(@compiler, dep).translate unless dep.jst }
          @@total_gen += Benchmark.realtime { Shin::Generator.new(dep).generate unless dep.code }
        end

        deps.each do |slug, dep|
          unless context.spec_loaded?(slug)
            context.load(slug)
          end
        end

        unless @to_array
          @__serialize_macro = context.eval(
            "$kir.modules['cljs.core'].exports.$_$_serialize$_macro")
          raise "--serialize-macro not a func?" unless V8::Function === @__serialize_macro
        end

        macro_slug = info[:module].slug
        macro_sexp = info[:macro]
        debug "Macro sexp:\n\n  #{macro_sexp}\n\n" if DEBUG

        macro_args = invoc.inner.to_a.drop(1)
        macro_gifted_args = macro_args.map { |arg| unwrap(arg) }
      end

      serialized_output = nil
      macro_name = invoc.inner.first.value

      @@total_call += Benchmark.realtime do
        macro_func = context.eval("$kir.modules['#{macro_slug}'].exports.#{mangle(macro_name)}")
        unless macro_func
          raise "Could not retrieve macro_func"
        end
        serialized_output = @__serialize_macro.call(macro_func, macro_gifted_args)
      end

      expanded_ast = nil

      @@total_deserialize += Benchmark.realtime do
        @v8.enter do
          expanded_ast = deserialize(serialized_output.native, invoc.token)
        end
        debug "Original AST:\n\n  #{invoc}\n\n" if DEBUG
        debug "Expanded AST:\n\n  #{expanded_ast}\n\n" if DEBUG
      end

#       puts "Total prep:           #{(1000 * @@total_prep).round(0)}ms"
#       puts "  Total nsp:          #{(1000 * @@total_nsp).round(0)}ms"
#       puts "  Total mut:          #{(1000 * @@total_mut).round(0)}ms"
#       puts "  Total trn:          #{(1000 * @@total_trn).round(0)}ms"
#       puts "  Total gen:          #{(1000 * @@total_gen).round(0)}ms"
#       puts "Total call:           #{(1000 * @@total_call).round(0)}ms"
#       puts "Total deserialize:    #{(1000 * @@total_deserialize).round(0)}ms"

      expanded_ast
    end

    
    private

    def deserialize(node, token)
      raise "Expected V8::C::Array, got #{node.class}: #{@v8.to_ruby(node)}" unless V8::C::Array === node

      type = node.Get(0)

      case type
      when 74 # nil
        Shin::AST::Symbol.new(token, nil)
      when 0 # mimic
        @v8.to_ruby(node.Get(1))
      when 1 # vector
        acc = []
        deserialize_v8_array(node, token, acc)
        Shin::AST::Vector.new(token, Hamster::Vector.new(acc))
      when 2 # list
        acc = []
        deserialize_v8_array(node, token, acc)
        Shin::AST::List.new(token, Hamster::Vector.new(acc))
      when 3 # map
        raise "map"
      when 4 # symbol
        Shin::AST::Symbol.new(token, @v8.to_ruby(node.Get(1)))
      when 5 # keyword
        Shin::AST::Keyword.new(token, @v8.to_ruby(node.Get(1)))
      when 6 # non-spliced unquote
        deserialize(node.Get(1), token)
      when 7 # splicing unquote
        raise "Invalid use of splicing unquote"
      when 8 # literal
        inner = node.Get(1)
        case inner
        when Fixnum, Float, true, false, nil
          Shin::AST::Literal.new(token, inner)
        when V8::C::String
          Shin::AST::Literal.new(token, @v8.to_ruby(inner))
        else
          raise "Unknown literal: #{inner}"
        end
      end
    end

    def deserialize_v8_array(arr, token, acc)
      len = arr.Length
      i = 1

      while i < len do
        el = arr.Get(i)
        type  = el.Get(0)

        case type
        when 7 # splicing unquote
          # splicing unquote
          inner = el.Get(1)
          case inner_type = inner.Get(0)
          when 0 # AST node
            @v8.to_ruby(inner.Get(1)).inner.each { |x| acc << x }
          when 1, 2 # list
            deserialize_v8_array(inner, token, acc)
          when 74 # nil
            # muffin!
          else
            raise "Invalid usage of splicing unquote on type #{inner_type}"
          end
        else
          acc << deserialize(el, token)
        end

        i += 1
      end
    end

    def debug(*args)
      puts("[FM] #{args.join(" ")}") if DEBUG
    end

  end
end

