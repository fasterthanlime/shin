
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
      debug "Should expand #{invoc}"

      deps = @compiler.collect_deps(info[:module])
      debug "Got deps: #{deps.keys}"

      all_in_cache = deps.keys.all? { |slug| @compiler.modules.include?(slug) }
      debug "All in cache? #{all_in_cache}"

      deps.each do |slug, dep|
        Shin::NsParser.new(dep).parse unless dep.ns
        Shin::Mutator.new(@compiler, dep).mutate unless dep.ast2
        Shin::Translator.new(@compiler, dep).translate unless dep.jst
        Shin::Generator.new(dep).generate unless dep.code
        puts "Compiled dep #{slug}"
      end

      deps.each do |slug, dep|
        context.load(slug)
      end

      all_loaded = deps.keys.all? { |slug| context.spec_loaded?(context.parse_spec(slug)) }
      debug "All loaded? #{all_loaded}"

      macro_slug = info[:module].slug
      debug "macro_slug: #{macro_slug}"

      macro_name = invoc.inner.first.value
      debug "macro_name: #{macro_name}"

      macro_func = context.eval("$kir.modules['#{macro_slug}'].exports.#{mangle(macro_name)}")
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
        debug "TODO: dequote the inside of nodes"
        # each, unquote, the works.
        node
      when Fixnum, Float, String
        Shin::AST::Literal.new(token, node)
      when V8::Object
        type = v8_type(node)
        debug "TODO: dequote a V8 object of type #{type}"
        nil
      end
    end
    
    private

    def debug(*args)
      puts("[FAST MUTATOR] #{args.join(" ")}") if DEBUG
    end

  end
end

