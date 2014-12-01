
require 'oj'
require 'shin/jst'
require 'shin/js_context'

module Shin
  # Generates JavaScript code from a given JST
  class Generator 
    DEBUG = ENV['GENERATOR_DEBUG']

    def initialize(mod)
      @mod = mod
    end

    def generate
      # `:object` is the fastest mode for Oj
      # we assign `@type` in every JST node's constructor
      # Oj will generate an extra ':^o' entry but it's still faster
      # than using compat mode + `to_hash` implementations.
      jst_json = Oj.dump(@mod.jst, :mode => :object)
      if DEBUG
        puts "JST json for #{@mod.slug}:\n\n#{Oj.dump(@mod.jst, :mode => :object, :indent => 2)}"
      end

      # fastest way to pass a big string to V8
      context.set("jst_json", jst_json)

      # it's faster to call JSON.parse from JS than to eval the JSON
      @mod.code = context.eval("escodegen.generate(JSON.parse(jst_json))")
    end

    def context
      unless defined? @@context
        @@context = Shin::JsContext.new
        @@context.load("escodegen")

        @@context.context['debug'] = lambda do |_, *args|
          puts "[gen debug] #{args.join(" ")}"
        end
      end
      @@context
    end
  end
end

