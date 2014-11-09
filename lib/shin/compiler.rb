
require 'shin/parser'
require 'shin/generator'

module Shin
  class Compiler
    def initialize
      
    end

    def compile(source, options = {})
      parser = Shin::Parser.new(source)
      tree = parser.parse

      generator = Shin::Generator.new()
      code = generator.generate(tree)

      return {
        :code => code
      }
    end
    
  end
end
