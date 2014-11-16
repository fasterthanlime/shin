
module Shin
  # Applies transformations to the Shin AST
  # These might include:
  #   - Macro expansions
  #   - Desugaring
  #   - Optimizations
  class Mutator

    attr_reader :mod

    def initialize(mod)
      @mod = mod
    end

    def mutate
      mod.ast2 = mod.ast
    end

  end
end

