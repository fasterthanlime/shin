
require 'slop'
require 'oj'
require 'benchmark'

require 'shin'
require 'shin/compiler'

class String
  def black;          "\033[30m#{self}\033[0m" end
  def red;            "\033[31m#{self}\033[0m" end
  def green;          "\033[32m#{self}\033[0m" end
  def brown;          "\033[33m#{self}\033[0m" end
  def blue;           "\033[34m#{self}\033[0m" end
  def magenta;        "\033[35m#{self}\033[0m" end
  def cyan;           "\033[36m#{self}\033[0m" end
  def gray;           "\033[37m#{self}\033[0m" end
  def bg_black;       "\033[40m#{self}\033[0m" end
  def bg_red;         "\033[41m#{self}\033[0m" end
  def bg_green;       "\033[42m#{self}\033[0m" end
  def bg_brown;       "\033[43m#{self}\033[0m" end
  def bg_blue;        "\033[44m#{self}\033[0m" end
  def bg_magenta;     "\033[45m#{self}\033[0m" end
  def bg_cyan;        "\033[46m#{self}\033[0m" end
  def bg_gray;        "\033[47m#{self}\033[0m" end
  def bold;           "\033[1m#{self}\033[22m" end
  def reverse_color;  "\033[7m#{self}\033[27m" end
end

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

      begin
        compiler = Shin::Compiler.new(opts)
        compile_time = 1000 * Benchmark.realtime do
          compiler.compile(source, :file => file)
        end
        puts "Compiled #{file || "<stdin>"} in #{compile_time.round(0)}ms".green if opts[:output]
      rescue SyntaxError => e
        puts "\n[ERROR] #{e.message}".red
        if ENV['DEBUG']
          puts e.backtrace.to_s.red
        end
      end
    end
  end
end

