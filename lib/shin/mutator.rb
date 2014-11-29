
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
    @@sym_seed = 2121

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

      debug "Mutating #{mod.slug}"
      mod.mutating = true
      mod.ast2 = mod.ast.map { |x| expand(x) }

      # we've probably been generating ourselves while mutating, so null those
      # so that the compiler doesn't over-cache things.
      mod.jst = nil
      mod.code = nil
    end

    protected

    def expand(node)
      case node
      when List
        first = node.inner.first
        case first
        when Symbol
          invoc = node
          info = resolve_macro(first.value)
          if info
            # debug "Should expand macro invoc\n\n#{invoc}\n\nwith\n\n#{info[:macro]}\n\n" if DEBUG

            eval_mod = make_macro_module(invoc, info)

            debug "=============================================="
            debug "; Macro :\n#{info[:macro]}\n\n" if DEBUG

            debug "; Original AST:\n#{invoc}\n\n" if DEBUG
            expanded_ast = eval_macro_module(eval_mod)

            node = expand(expanded_ast)
          end
        end
      end

      if Sequence === node
        inner = node.inner
        inner.each_with_index do |child, i|
          poster_child = expand(child)
          inner = inner.set(i, poster_child) if poster_child != child
        end

        if inner != node.inner
          node = node.class.new(node.token, inner)
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
          # debug "Generated macro code from #{macros.slug}"
        end

        defs = macros.defs
        res = defs[name]
        if res
          # debug "Found '#{name}' in #{macros.slug}, which has defs #{defs.keys.join(", ")}" if DEBUG
          return {:macro => res, :module => macros}
        end
      end

      nil
    end

    def make_macro_module(invoc, info)
      # debug "Making macro_eval module for #{@mod.slug}"

      t = invoc.token
      macro_sym = invoc.inner.first

      eval_mod = Shin::Module.new
      eval_mod.macro = true
      _yield = Symbol.new(t, "yield")
      pr_str = Symbol.new(t, "pr-str")

      eval_args = Hamster.vector(macro_sym)
      invoc.inner.drop(1).each do |arg|
        eval_args <<= SyntaxQuote.new(arg.token, arg)
      end
      eval_node = List.new(t, eval_args)

      eval_ast = List.new(t, Hamster.vector(_yield, List.new(t, Hamster.vector(pr_str, eval_node))))
      eval_mod.ast = eval_mod.ast2 = [eval_ast]

      info_ns = info[:module].ns
      req = Shin::Require.new(info_ns, :macro => true, :refer => :all)
      eval_mod.requires << req

      eval_mod.source = @mod.source
      Shin::NsParser.new(eval_mod).parse
      Shin::Translator.new(@compiler, eval_mod).translate
      Shin::Generator.new(eval_mod).generate

      deps = @compiler.collect_deps(eval_mod)

      deps.each do |slug, dep|
        next if slug == eval_mod.ns
        Shin::NsParser.new(dep).parse unless dep.ns
        Shin::Mutator.new(@compiler, dep).mutate unless dep.ast2
        Shin::Translator.new(@compiler, dep).translate unless dep.jst
        Shin::Generator.new(dep).generate unless dep.code
      end

      eval_mod
    end

    def eval_macro_module(eval_mod)
      js = js_context

      result = nil
      js.context['yield'] = lambda do |_, ast_back|
        result = ast_back
      end
      begin
        js.load(eval_mod.code, :inline => true)
      rescue => e
        puts "While trying to load:\n\n#{eval_mod.code}\n\n"
        raise e
      end

      res_parser = Shin::Parser.new(result.to_s)
      expanded_ast = res_parser.parse.first
      debug "; Expanded AST:\n#{expanded_ast}\n\n" if DEBUG

      dequoted_ast = dequote(expanded_ast)
      debug "; Dequoted AST:\n#{dequoted_ast}\n\n" if DEBUG

      dequoted_ast
    end

    def js_context
      unless @js_context
        js = @js_context = Shin::JsContext.new
        js.context['fresh_sym'] = lambda do |_|
          return Mutator.fresh_sym
        end

        js.context['debug'] = lambda do |_, *args|
          debug "[from JS] #{args.join(" ")}"
        end

        js.providers << @compiler
      end
      @js_context
    end

    def dequote(node)
      case node
      when Sequence
        inner = node.inner

        offset = 0
        inner.each_with_index do |child, i|
          poster_child = dequote(child)
          if poster_child != child
            case poster_child
            when Hamster::Vector
              inner = inner.delete_at(i + offset)
              offset -= 1
              poster_child.each do |el|
                offset += 1
                inner = inner.insert(i + offset, el)
              end
            when nil
              inner = inner.delete_at(i + offset)
              offset -= 1
            else
              inner = inner.set(i + offset, poster_child)
            end
          end
        end

        if node.inner == inner
          node
        else
          node.class.new(node.token, inner)
        end
      when Unquote
        if Deref === node.inner
          deref = node.inner

          case
          when Sequence === deref.inner
            deref.inner.inner.map { |x| dequote(x) }
          when deref.inner.sym?("nil")
            nil
          else
            ser!("Cannot use splicing on non-list form #{deref.inner}")
          end

        else
          dequote(node.inner)
        end
      else
        node
      end
    end

    def fresh
      @seed += 1
    end

    def self.fresh_sym
      @@sym_seed += 1
    end

    def debug(*args)
      puts("[MUTATOR] #{args.join(" ")}") if DEBUG
    end

    def ser!(msg)
      raise msg
    end
  end
end

