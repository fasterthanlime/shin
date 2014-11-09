
require 'shin/parser'
require 'shin/generator'

module Shin
  class Compiler
    def initialize
      
    end

    def compile(source, options = {})
      tree = parser.parse(source)
      code = generator.generate(tree)

      return {
        :code => code
      }
    end

    private

    def parser
      @parser ||= Shin::Parser.new
    end

    def generator
      @generator ||= Shin::Generator.new
    end
    
  end
end
