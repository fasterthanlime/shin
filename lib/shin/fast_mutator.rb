
module Shin
  class FastMutator
    DEBUG = true

    def initialize(compiler, mod)
      @compiler = compiler
      @mod = mod
    end

    def expand(invoc, info, context)
      debug "Should expand #{invoc}"

      args = invoc.inner.drop(1).to_a
      debug "Got args: #{args.join(", ")}"

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

      raise
      invoc
    end
    
    private

    def debug(*args)
      puts("[FAST MUTATOR] #{args.join(" ")}") if DEBUG
    end

  end
end

