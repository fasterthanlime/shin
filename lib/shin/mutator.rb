
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
                Shin::Translator.new(@compiler, macros).translate
                Shin::Generator.new(macros).generate
                puts "Generated macro code #{macros.code}"
              end
            end
          end
        end
      end

      node
    end

  end
end

