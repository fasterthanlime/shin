
require 'shin/ast'

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
            defs = macros.defs
            res = defs[first.value]
            if res
              puts "Should expand #{first} with #{res}"
              unless macros.code
                Shin::NsParser.new(macros).parse
                Shin::Translator.new(@compiler, macros).translate
                Shin::Generator.new(macros).generate
                puts "Generated macro code #{macros.code}"
              end

              puts "eval_ast = #{node}"
              eval_mod = Shin::Module.new

              ysym = Symbol.new(node.token, "yield")
              eval_ast = List.new(node.token, [ysym, node])
              eval_mod.ast = [eval_ast]

              eval_mod.source = @mod.source
              Shin::NsParser.new(eval_mod).parse
              Shin::Translator.new(@compiler, eval_mod).translate
              Shin::Generator.new(eval_mod).generate
              puts "eval_mod.code = #{eval_mod.code}"
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

