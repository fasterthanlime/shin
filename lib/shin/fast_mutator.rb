
module Shin
  class FastMutator
    DEBUG = true

    def initialize(compiler, mod)
      @compiler = compiler
      @mod = mod
    end

    def expand(invoc, info)
      debug "Should expand #{invoc}"
      invoc
    end
    
    private

    def debug(*args)
      puts("[FAST MUTATOR] #{args.join(" ")}") if DEBUG
    end

  end
end

