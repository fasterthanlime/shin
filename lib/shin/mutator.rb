
module Shin
  # Applies transformations to the Shin AST
  # These might include:
  #   - Macro expansions
  #   - Desugaring
  #   - Optimizations
  class Mutator

    def mutate(mod)
      mod.ast2 = mod.ast
    end

  end
end

