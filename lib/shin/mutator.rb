
require 'shin/ast'
require 'shin/js_context'

module Shin
  # Applies transformations to the Shin AST
  # These might include:
  #   - Macro expansions
  #   - Desugaring
  #   - Optimizations
  class Mutator
    include Shin::AST

    attr_reader :mod

    def initialize(compiler, mod)
      @compiler = compiler
      @mod = mod
      @seed = 0
    end

    def mutate
      if @mod.is_macro
        # FIXME: this is probably wrong?
        mod.ast2 = mod.ast
        return
      end

      mod.ast2 = mod.ast.map { |x| expand(x) }
    end

    def expand(node)
      case node
      when List
        first = node.inner.first
        case first
        when Symbol
          macros = @mod.macros
          if macros
            unless macros.code
              Shin::NsParser.new(macros).parse
              Shin::Mutator.new(@compiler, macros).mutate
              Shin::Translator.new(@compiler, macros).translate
              Shin::Generator.new(macros).generate
              @compiler.modules << macros
              puts "Generated macro code #{macros.code}"
            end

            defs = macros.defs
            puts "Defs in macros: #{defs}"
            res = defs[first.value]
            if res
              puts "Should expand #{first} with #{res}"

              puts "eval_ast = #{node}"
              eval_mod = Shin::Module.new

              _yield = Symbol.new(node.token, "yield")
              pr_str = Symbol.new(node.token, "pr-str")
              eval_ast = List.new(node.token, [_yield, List.new(node.token, [pr_str, node])])
              eval_mod.ast = [eval_ast]
              eval_mod.requires << {
                :type => 'use',
                :name => macros.ns,
                :aka => macros.ns
              }

              eval_mod.source = @mod.source
              Shin::NsParser.new(eval_mod).parse
              Shin::Translator.new(@compiler, eval_mod).translate
              Shin::Generator.new(eval_mod).generate
              puts "eval_mod.code = #{eval_mod.code}"

              deps = @compiler.collect_deps(eval_mod)
              deps.each do |ns, dep|
                Shin::NsParser.new(dep).parse
                Shin::Translator.new(@compiler, dep).translate
                Shin::Generator.new(dep).generate
              end

              js = Shin::JsContext.new
              result = nil
              js.context['yield'] = lambda do |res|
                result = res
              end
              js.providers << @compiler
              js.load(eval_mod.code, :inline => true)

              puts "Got result back: #{result}"
            end
          end
        end
      end

      node
    end

    def fresh
      @seed += 1
    end

  end
end

