
require 'shin/ast'
require 'shin/js_context'
require 'shin/utils/mangler'

module Shin
  class MacroExpander
    include Shin::Utils::Mangler
    include Shin::Utils::Mimic

    DEBUG = ENV['MACRO_DEBUG']

    attr_reader :context
    attr_reader :mod

    @@total_prep = 0
    @@total_call = 0
    @@total_deserialize = 0
    @@total_nsp = 0      
    @@total_mut = 0    
    @@total_trn = 0
    @@total_gen = 0

    def initialize(compiler, mod)
      @compiler = compiler
      @mod = mod
      @seed = 0
      @context = js_context
      @v8 = @context.context
    end

    def expand_macros
      if mod.mutating
        # FIXME oh god this is a terrible workaround.
        mod.ast2 = mod.ast
        return
      end

      debug "Expanding macros #{mod.slug}"
      mod.mutating = true
      mod.ast2 = mod.ast.map do |x|
        expand(x)
      end
      mod.mutating = false

      # we've probably been generating ourselves while mutating, so null those
      # so that the compiler doesn't over-cache things.
      mod.jst = nil
      mod.code = nil
      context.unload!(mod.slug)
    end

    private

    def expand(node)
      case node
      when AST::List
        first = node.inner.first
        case first
        when AST::Symbol
          invoc = node
          info = resolve_macro(first.value)
          if info
            expanded_ast = invoke_macro(invoc, info)
            node = expand(expanded_ast)
          end
        end
      end

      if AST::Sequence === node
        inner = node.inner
        index = 0
        inner.each do |child|
          poster_child = expand(child)
          inner = inner.set(index, poster_child) if poster_child != child
          index += 1
        end

        if inner != node.inner
          node = node.class.new(node.token, inner)
        end
      end

      node
    end

    def invoke_macro(invoc, info)
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
          @@total_nsp += Benchmark.realtime { NsParser.new(dep).parse unless dep.ns }
          @@total_mut += Benchmark.realtime { MacroExpander.new(@compiler, dep).expand_macros unless dep.ast2 }
          @@total_trn += Benchmark.realtime { Translator.new(@compiler, dep).translate unless dep.jst }
          @@total_gen += Benchmark.realtime { Generator.new(dep).generate unless dep.code }
        end

        deps.each do |slug, dep|
          unless context.loaded?(slug)
            context.load(slug)
          end
        end

        @__serialize_macro = context.eval("$kir.modules['cljs.core'].exports.$_$_serialize$_macro")
        raise "--serialize-macro not a func?" unless V8::Function === @__serialize_macro

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
      debug "Serialized output: #{serialized_output}" if DEBUG

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
        AST::Symbol.new(token, "nil")
      when 0 # mimic
        @v8.to_ruby(node.Get(1))
      when 1 # vector
        acc = []
        deserialize_v8_array(node, token, acc)
        AST::Vector.new(token, Hamster::Vector.new(acc))
      when 2 # list
        acc = []
        deserialize_v8_array(node, token, acc)
        AST::List.new(token, Hamster::Vector.new(acc))
      when 3 # map
        raise "map"
      when 4 # symbol
        AST::Symbol.new(token, @v8.to_ruby(node.Get(1)))
      when 5 # keyword
        AST::Keyword.new(token, @v8.to_ruby(node.Get(1)))
      when 6 # non-spliced unquote
        deserialize(node.Get(1), token)
      when 7 # splicing unquote
        raise "Invalid use of splicing unquote"
      when 8 # literal
        inner = node.Get(1)
        case inner
        when Fixnum, Float, true, false, nil
          AST::Literal.new(token, inner)
        when V8::C::String
          AST::Literal.new(token, @v8.to_ruby(inner))
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


    def resolve_macro(name)
      @mod.requires.each do |req|
        next unless req.macro?

        dep = @compiler.modules[req]
        res = dep.scope.form_for(name)
        if res
          # debug "Found '#{name}' in #{dep.slug}, which has defs #{defs.keys.join(", ")}" if DEBUG
          return {:macro => res, :module => dep}
        end
      end

      nil
    end

    def js_context
      unless defined?(@@js_context)
        js = @@js_context = Shin::JsContext.new
        js.context['debug'] = lambda do |_, *args|
          debug "[from JS] #{args.join(" ")}"
        end

        js.providers << @compiler
      end
      @@js_context
    end

    def debug(*args)
      puts("[MACRO] #{args.join(" ")}") if DEBUG
    end

  end
end

