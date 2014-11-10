
require 'shin/parser'
require 'shin/mutator'
require 'shin/translator'
require 'shin/generator'

module Shin
  class Compiler
    def self.compile_file(path)
      Shin::Compiler.new.compile(File.read(path), :file => path)
    end

    def initialize
      # muffin to do.
    end

    def compile(source, options = {})
      parser = Shin::Parser.new(source, options)
      ast = parser.parse

      mutator = Shin::Mutator.new
      ast2 = mutator.mutate(ast)

      translator = Shin::Translator.new(parser.input, options)
      jst = translator.translate(ast2)

      generator = Shin::Generator.new
      code = generator.generate(jst)

      return {
        :ast => ast,
        :ast2 => ast2,
        :jst => jst,
        :code => code
      }
    end
    
  end
end
