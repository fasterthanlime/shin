
require 'shin/utils/mangler'

module Shin
  class FastMutator
    include Shin::Utils::Mangler
    include Shin::Utils::Mimic

    DEBUG = true

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
      when Shin::AST::Node
        node
      when Fixnum, Float, String
        Shin::AST::Literal.new(token, node)
      when V8::Object
        type = v8_type(node)
        case type
        when :list
          acc = []
          xs = node
          while xs
            el = js_invoke(xs, '-first')
            acc << unquote(el, token)
            xs = js_invoke(xs, '-next')
          end
          Shin::AST::List.new(token, Hamster::Vector.new(acc))
        when :symbol
          Shin::AST::Symbol.new(token, node['_name'])
        when :unquote
          if node['splice']
            raise "Dunno how to unquote-splice yet!"
          end
          unquote(node['inner'], token)
        else
          raise "Dunno how to dequote a V8 object of type #{type}"
        end
      end
    end
    
    private

    def debug(*args)
      puts("[FAST MUTATOR] #{args.join(" ")}") if DEBUG
    end

  end
end

