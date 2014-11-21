
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
      jst_json = Oj.dump(@mod.jst, :mode => :compat, :indent => 2)
      context.set("jst_json", jst_json)
      debug "JST json for #{@mod.slug}:\n\n#{jst_json}"
      @mod.code = context.eval("escodegen.generate(JSON.parse(jst_json))")
    end

    def context
      unless defined? @@context
        @@context = Shin::JsContext.new
        @@context.load("escodegen")
      end
      @@context
    end

    private

    def debug(*args)
      puts(*args) if DEBUG
    end
  end
end

