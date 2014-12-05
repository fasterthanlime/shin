
require 'shin/utils/mangler'

module Shin
  class FastMutator
    include Shin::Utils::Mangler
    include Shin::Utils::Mimic

    DEBUG = ENV['FAST_MUTATOR_DEBUG']

    attr_reader :context
    @@total_prep = 0
    @@total_serial = 0
    @@total_serial2 = 0
    @@total_serial3 = 0
    @@total_unquote = 0
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
      debug "Expanding #{invoc}" if DEBUG

      macro_gifted_args = nil
      macro_func = nil
      macro_slug = nil

      @@total_prep += Benchmark.realtime do
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
          @to_array = context.eval("$kir.modules['cljs.core'].exports.to$_array")
          raise "to-array not a func?" unless V8::Function === @to_array

          @__serialize = context.eval("$kir.modules['cljs.core'].exports.$_$_serialize")
          raise "--serialize not a func?" unless V8::Function === @__serialize

          @__serialize_macro = context.eval("$kir.modules['cljs.core'].exports.$_$_serialize$_macro")
          raise "--serialize-macro not a func?" unless V8::Function === @__serialize_macro
        end

        macro_slug = info[:module].slug
        debug "macro_slug: #{macro_slug}" if DEBUG

        macro_sexp = info[:macro]
        debug "macro_sexp: #{macro_sexp}" if DEBUG

        macro_args = invoc.inner.to_a.drop(1)
        debug "macro_args: #{macro_args.join(", ")}" if DEBUG

        macro_gifted_args = macro_args.map { |arg| unwrap(arg) }
        debug "macro_gifted_args: #{macro_gifted_args.join(", ")}" if DEBUG
      end

      macro_ret = nil
      macro_ret_unquoted = nil

      macro_name = invoc.inner.first.value
      debug "macro_name: #{macro_name}" if DEBUG

      @@total_serial += Benchmark.realtime do
        num_args = macro_gifted_args.length
        arg_list = (0...num_args).map { |i| "arg#{i}" }.join(", ")

        serial_macro_func = @v8.eval(%Q{
          var core = $kir.modules['cljs.core'].exports;
          var womb = $kir.modules['#{macro_slug}'].exports;
          var f = function (#{arg_list}) {
            return core.$_$_serialize(womb.#{mangle(macro_name)}(#{arg_list}));
          };
          f
        })
        serialized_output = serial_macro_func.call(*macro_gifted_args)

        # yay experimental stuff
        @v8.enter do
          deser = deserialize(serialized_output.native, invoc.token)
          # puts "deser = #{deser}"
        end
      end

      @@total_serial2 += Benchmark.realtime do
        macro_func = context.eval("$kir.modules['#{macro_slug}'].exports.#{mangle(macro_name)}")
        unless macro_func
          raise "Could not retrieve macro_func"
        end
        serial_macro_ret = macro_func.call(*macro_gifted_args)
        serialized_output = @__serialize.call(serial_macro_ret)

        # yay experimental stuff
        @v8.enter do
          deser = deserialize(serialized_output.native, invoc.token)
          # puts "deser = #{deser}"
        end
      end

      @@total_serial3 += Benchmark.realtime do
        macro_func = context.eval("$kir.modules['#{macro_slug}'].exports.#{mangle(macro_name)}")
        unless macro_func
          raise "Could not retrieve macro_func"
        end
        serialized_output = @__serialize_macro.call(macro_func, macro_gifted_args)

        # yay experimental stuff
        @v8.enter do
          deser = deserialize(serialized_output.native, invoc.token)
          # puts "deser = #{deser}"
        end
      end

      @@total_unquote += Benchmark.realtime do
        macro_func = context.eval("$kir.modules['#{macro_slug}'].exports.#{mangle(macro_name)}")
        unless macro_func
          raise "Could not retrieve macro_func"
        end
        debug "macro_func: #{macro_func}" if DEBUG
        macro_ret = macro_func.call(*macro_gifted_args)
        debug "macro_ret: #{macro_ret}" if DEBUG

        macro_ret_unquoted = unquote(macro_ret, invoc.token)
        debug "unquoted macro_ret: #{macro_ret_unquoted}" if DEBUG
      end
      # puts "Total prep:    #{(1000 * @@total_prep).round(0)}ms"
      # puts "  Total nsp:    #{(1000 * @@total_nsp).round(0)}ms"
      # puts "  Total mut:    #{(1000 * @@total_mut).round(0)}ms"
      # puts "  Total trn:    #{(1000 * @@total_trn).round(0)}ms"
      # puts "  Total gen:    #{(1000 * @@total_gen).round(0)}ms"
      puts "#{(1000 * @@total_serial).round(0)} ms  - Total serial"
      puts "#{(1000 * @@total_serial2).round(0)} ms - Total serial2"
      puts "#{(1000 * @@total_serial3).round(0)} ms - Total serial3"
      puts "#{(1000 * @@total_unquote).round(0)} ms - Total unquote"

      macro_ret_unquoted
    end

    def unquote(node, token)
      case node
      when Fixnum, Float, String, true, false, nil
        Shin::AST::Literal.new(token, node)
      when Shin::AST::Node
        node
      when V8::Object
        type = v8_type(node)
        case type
        when :list
          acc = unquote_coll(node, token)
          Shin::AST::List.new(token, Hamster::Vector.new(acc))
        when :vector
          acc = unquote_coll(node, token)
          Shin::AST::Vector.new(token, Hamster::Vector.new(acc))
        when :symbol
          Shin::AST::Symbol.new(token, node['_name'])
        when :unquote
          if node['splice']
            raise "Invalid usage of splice outside a collection"
          end
          unquote(node['inner'], token)
        else
          raise "Dunno how to dequote a V8 object of type #{type}"
        end
      end
    end
    
    private

    def unquote_coll(node, token)
      acc = []
      @to_array.call(node).each do |el|
        spliceful_append(acc, el, token)
      end
      acc
    end

    def spliceful_append(acc, el, token)
      if (V8::Object === el) && (v8_type(el) == :unquote) && el['splice']
        inner = el['inner']

        case inner
        when nil
          # well that's good, just don't append anything.
        when V8::Object
          inner_type = v8_type(inner)
          case inner_type
          when :list, :vector
            acc.concat(unquote_coll(inner, token))
          else
            raise "Invalid use of splice on non-sequence V8 object #{inner_type} #{inner['toString'].methodcall(inner)}"
          end
        when AST::List, AST::Vector
          inner.inner.each { |x| acc << x }
        else
          raise "Invalid use of splice on non-sequence #{inner.inspect}"
        end
      else
        acc << unquote(el, token)
      end
    end

    # yay experimental stuff

    def deserialize(node, token)
      raise "Expected V8::C::Array" unless V8::C::Array === node

      type =  node.Get(0)
      inner = node.Get(1)

      case type
      when 74 # nil
        Shin::AST::Symbol.new(token, nil)
      when 0 # mimic
        @v8.to_ruby(inner)
      when 1 # vector
        acc = []
        deserialize_all(inner, token, acc)
        Shin::AST::Vector.new(token, Hamster::Vector.new(acc))
      when 2 # list
        acc = []
        deserialize_all(inner, token, acc)
        Shin::AST::List.new(token, Hamster::Vector.new(acc))
      when 3 # map
        raise "map"
      when 4 # symbol
        Shin::AST::Symbol.new(token, @v8.to_ruby(inner))
      when 5 # keyword
        Shin::AST::Keyword.new(token, @v8.to_ruby(inner))
      when 6 # non-spliced unquote
        deserialize(inner, token)
      when 7 # splicing unquote
        raise "Invalid use of splicing unquote"
      when 8 # literal
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

    def deserialize_all(arr, token, acc)
      len = arr.Length
      i = 0

      while i < len do
        el = arr.Get(i)
        type  = el.Get(0)

        if type == 7
          # splicing unquote
          deserialize_all(el.Get(1), token, acc)
        else
          acc << deserialize(el, token)
        end

        i += 1
      end
    end

    def debug(*args)
      puts("[FAST MUTATOR] #{args.join(" ")}") if DEBUG
    end

  end
end

