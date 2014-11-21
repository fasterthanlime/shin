
require 'shin/ast'
require 'shin/js_context'

module Shin
  # Applies transformations to the Shin AST
  # These might include:
  #   - Macro expansions
  #   - Desugaring
  #   - Optimizations
  class Mutator
    DEBUG = ENV['MUTATOR_DEBUG']

    include Shin::AST

    attr_reader :mod

    def initialize(compiler, mod)
      @compiler = compiler
      @mod = mod
      @seed = 0
    end

    def mutate
      if mod.mutating
        # FIXME oh god this is a terrible workaround.
        mod.ast2 = mod.ast
        return
      end

      if @mod.macro?
        # FIXME: this is probably wrong? or is it?
        mod.ast2 = mod.ast
        return
      end

      debug "Mutating #{mod.slug}"
      mod.mutating = true
      mod.ast2 = mod.ast.map { |x| expand(x) }
    end

    protected

    def expand(node)
      if Sequence === node
        # FIXME: mutator isn't supposed to mutate the old AST. is clone a proper fix?
        node = node.clone
        node.inner.map! { |x| expand(x) }
      end

      case node
      when List
        first = node.inner.first
        case first
        when Symbol
          invoc = node
          info = resolve_macro(first.value)
          if info
            debug "Should expand macro invoc\n\n#{invoc}\n\nwith\n\n#{info[:macro]}\n\n"

            eval_mod = make_macro_module(invoc, info)
            expanded_ast = eval_macro_module(eval_mod)
            return expanded_ast
          end
        end
      end

      node
    end

    def resolve_macro(name)
      @mod.requires.each do |req|
        next unless req.macro?

        macros = @compiler.modules[req]

        # compile macro code if needed
        unless macros.code
          Shin::NsParser.new(macros).parse
          Shin::Mutator.new(@compiler, macros).mutate
          Shin::Translator.new(@compiler, macros).translate
          Shin::Generator.new(macros).generate
          @compiler.modules << macros
          debug "Generated macro code for #{macros.ns}."
        end

        defs = macros.defs
        res = defs[name]
        if res
          debug "Found '#{name}' in #{macros.slug}, which has defs #{defs.keys.join(", ")}"
          return {:macro => res, :module => macros}
        end
      end

      nil
    end

    def make_macro_module(invoc, info)
      debug "Making macro_eval module for #{@mod.slug}"

      t = invoc.token
      macro_sym = invoc.inner.first

      eval_mod = Shin::Module.new
      eval_mod.macro = true
      _yield = Symbol.new(t, "yield")
      pr_str = Symbol.new(t, "pr-str")

      eval_node = List.new(t, [macro_sym])
      invoc.inner.drop(1).each do |arg|
        eval_node.inner << SyntaxQuote.new(arg.token, arg)
      end

      eval_ast = List.new(t, [_yield, List.new(t, [pr_str, eval_node])])
      eval_mod.ast = eval_mod.ast2 = [eval_ast]

      info_ns = info[:module].ns
      req = Shin::Require.new(info_ns, :macro => true, :refer => :all)
      eval_mod.requires << req
      debug "eval_mod ast =\n\n#{eval_mod.ast.join(" ")}\n\n"

      eval_mod.source = @mod.source
      Shin::NsParser.new(eval_mod).parse
      Shin::Translator.new(@compiler, eval_mod).translate
      Shin::Generator.new(eval_mod).generate

      debug "eval_mod got NS: #{eval_mod.ns}"
      debug "eval_mod code =\n\n#{eval_mod.code}\n\n"

      deps = @compiler.collect_deps(eval_mod)
      debug "deps for eval_mod: #{deps.keys.join(", ")}"
      deps.each do |slug, dep|
        next if slug == eval_mod.ns
        debug "Compiling dep #{dep.slug}"
        Shin::NsParser.new(dep).parse
        Shin::Mutator.new(@compiler, dep).mutate
        Shin::Translator.new(@compiler, dep).translate
        Shin::Generator.new(dep).generate
      end

      eval_mod
    end

    def eval_macro_module(eval_mod)
      js = Shin::JsContext.new
      result = nil
      js.context['yield'] = lambda do |_, ast_back|
        result = ast_back
      end
      js.providers << @compiler
      js.load(eval_mod.code, :inline => true)

      res_parser = Shin::Parser.new(result.to_s)
      expanded_ast = res_parser.parse.first
      debug "Expanded AST:\n\n#{expanded_ast}\n\n"

      dequoted_ast = dequote(expanded_ast)
      debug "Dequoted AST:\n\n#{dequoted_ast}\n\n"

      dequoted_ast
    end

    def dequote(node)
      case node
      when Sequence
        res = node.clone
        res.inner = []
        node.inner.each do |x|
          deq = dequote(x)
          if Array === deq
            deq.each { |x| res.inner << x }
          else
            res.inner << deq
          end
        end

        return res
      when Unquote
        if Deref === node.inner
          deref = node.inner
          unless Sequence === deref.inner
            ser!("Cannot use splicing on non-list form #{deref.inner}")
          end
          return deref.inner.inner.map { |x| dequote(x) }
        else
          return dequote(node.inner)
        end
      end

      node
    end

    def fresh
      @seed += 1
    end

    def debug(*args)
      puts("[MUTATOR] #{args.join(" ")}") if DEBUG
    end

    def ser!(msg)
      raise msg
    end
  end
end

