
require 'oj'
require 'shin/jst'
require 'shin/js_context'

module Shin
  # Generates JavaScript code from a given JST
  class Generator 
    def initialize
      # not much to do
    end

    def generate(jst)
      context = Shin::JsContext.new
      context.load("escodegen")

      jst_json = Oj.dump(jst, :mode => :compat, :indent => 2)
      context.set("jst_json", jst_json)
      context.eval("escodegen.generate(JSON.parse(jst_json))")
    end
  end
end

