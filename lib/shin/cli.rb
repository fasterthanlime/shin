
require 'slop'
require 'shin'
require 'oj'

module Shin
  class CLI
    def initialize
      opts = Slop.parse(:strict => true, :help => true) do
        banner 'Usage: shin [options] [programfile]'

        on 'e=', 'exec', 'Eval the given code and exit'
        on 'o=', 'output', 'Output directory', :default => "."
        on 'c', 'check', 'Check syntax only'
        on 'a', 'ast', 'Dump AST and exit'
        on 'A', 'ast2', 'Dump mutated AST (after macro expansion) and exit'
        on 'J', 'jst', 'Dump JST (Mozilla Parse API AST) and exit'
        on 'j', 'js', 'Dump generated JavaScript and exit'
        on 'V', 'version', 'Print version and exit'
      end

      if opts.version?
        puts "Shin, version #{Shin::VERSION}"
        exit 0
      end

      compiler_opts = {}
      if opts.exec?
        source = opts[:exec]
      else
        path = ARGV.first
        if path.nil?
          # TODO: start a REPL?
          puts "No program given"
          exit 1
        end

        source = File.read(path)
        compiler_opts[:file] = path
      end

      parser = Shin::Parser.new(source, compiler_opts) 
      ast = parser.parse

      if opts.check?
        exit 0
      end

      if opts.ast?
        puts Oj.dump(ast, :mode => :object, :indent => 2)
        exit 0
      end

      mutator = Shin::Mutator.new
      ast2 = mutator.mutate(ast)

      if opts.ast2?
        puts Oj.dump(ast2, :mode => :object, :indent => 2)
        exit 0
      end

      translator = Shin::Translator.new(parser.input, compiler_opts)
      jst = translator.translate(ast2)

      if opts.jst?
        puts Oj.dump(jst, :mode => :compat, :indent => 2)
        exit 0
      end

      generator = Shin::Generator.new
      code = generator.generate(jst)

      if opts.js?
        puts code
        exit 0
      end

      if opts.exec?
        js = JsContext.new
        js.context['print'] = lambda do |_, *args|
          print args.join(" ")
        end
        js.context['println'] = lambda do |_, *args|
          puts args.join(" ")
        end
        js.load(code, :inline => true)
      else
        # TODO: write the code somewhere.
      end
    end
  end
end

