
require 'slop'
require 'oj'
require 'benchmark'

require 'shin'
require 'shin/compiler'

module Shin
  class CLI
    def initialize
      opts = Slop.parse(:strict => true, :help => true) do
        banner 'Usage: shin [options] [programfile]'

        on 'e=', 'exec', 'Eval the given code and exit'
        on 'o=', 'output', 'Output directory', :default => "."
        on 'I=', 'sourcepath', ':require search path', :as => Array, :default => ["."]
        on 'L=', 'libpath', ':require-js search path', :as => Array, :default => []
        on 'c', 'check', 'Check syntax only'
        on 'S', 'sexpr', 'Dump parsed S-exprs and exit'
        on 'a', 'ast', 'Dump AST and exit'
        on 'A', 'ast2', 'Dump mutated AST (after macro expansion) and exit'
        on 'J', 'jst', 'Dump JST (Mozilla Parse API AST) and exit'
        on 'j', 'js', 'Dump generated JavaScript and exit'
        on 'V', 'version', 'Print version and exit'
        on 'p', 'profile', 'Profile the compiler', :default => false
      end

      if opts.version?
        puts "Shin, version #{Shin::VERSION}"
        exit 0
      end

      file = nil
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
        file = path
      end

      compiler = Shin::Compiler.new(opts)
      compile_time = Benchmark.measure do
        compiler.compile(source, :file => file)
      end
      puts "Total\t#{compile_time}"

      puts "Compiled #{file || "<stdin>"}" if opts[:output]
    end
  end
end

