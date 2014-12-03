
require 'shin/utils/mangler'

module Shin
  class FastMutator
    include Shin::Utils::Mangler
    include Shin::Utils::Mimic

    DEBUG = ENV['FAST_MUTATOR_DEBUG']

    def initialize(compiler, mod)
      @compiler = compiler
      @mod = mod
    end

    def expand(invoc, info, context)
      debug "Expanding #{invoc}"

      deps = @compiler.collect_deps(info[:module])

      all_in_cache = deps.keys.all? { |slug| @compiler.modules.include?(slug) }
      unless all_in_cache
        raise "Not all deps in cache: #{deps.keys}"
      end

      deps.each do |slug, dep|
        Shin::NsParser.new(dep).parse unless dep.ns
        Shin::Mutator.new(@compiler, dep).mutate unless dep.ast2
        Shin::Translator.new(@compiler, dep).translate unless dep.jst
        Shin::Generator.new(dep).generate unless dep.code
      end

      deps.each do |slug, dep|
        context.load(slug)
      end

      all_loaded = deps.keys.all? { |slug| context.spec_loaded?(context.parse_spec(slug)) }
      unless all_loaded
        raise "Not all loaded!"
      end

      macro_slug = info[:module].slug
      debug "macro_slug: #{macro_slug}"

      macro_name = invoc.inner.first.value
      debug "macro_name: #{macro_name}"

      macro_sexp = info[:macro]
      debug "macro_sexp: #{macro_sexp}"

      macro_func = context.context['$kir']['modules'][macro_slug]['exports'][mangle(macro_name)]
      unless macro_func
        raise "Could not retrieve macro_func"
      end
      debug "macro_func: #{macro_func}"

      macro_args = invoc.inner.drop(1).to_a
      debug "macro_args: #{macro_args.join(", ")}"

      macro_gifted_args = macro_args.map { |arg| unwrap(arg) }
      debug "macro_gifted_args: #{macro_gifted_args.join(", ")}"

      macro_ret = macro_func.call(*macro_gifted_args)
      debug "macro_ret: #{macro_ret}"

      macro_ret_unquoted = unquote(macro_ret, invoc.token)
      debug "unquoted macro_ret: #{macro_ret_unquoted}"

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
          acc = unquote_seq(node, token)
          Shin::AST::List.new(token, Hamster::Vector.new(acc))
        when :vector
          acc = unquote_indexed(node, token)
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

    def unquote_seq(node, token)
      acc = []
      xs = node
      while xs
        el = nil
        
        case xs
        when V8::Object
          el = js_invoke(xs, '-first')
          xs = js_invoke(xs, '-next')
        else
          el = xs.invoke('-first')
          xs = xs.invoke('-next')
        end
        spliceful_append(acc, el, token)
      end
      acc
    end

    def unquote_indexed(node, token)
      acc = []
      xs = node
      count = js_invoke(xs, '-count')
      (0...count).each do |i|
        el = js_invoke(xs, '-nth', i)
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
          when :list
            acc.concat(unquote_seq(inner, token))
          when :vector
            acc.concat(unquote_indexed(inner, token))
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

    def debug(*args)
      puts("[FAST MUTATOR] #{args.join(" ")}") if DEBUG
    end

  end
end

