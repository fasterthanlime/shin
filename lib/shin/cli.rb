
require 'slop'
require 'oj'

require 'shin'
require 'shin/utils'

module Shin
  class CLI
    include Shin::Utils::Matcher
    attr_accessor :opts
    attr_accessor :modules

    def initialize
      @fresh = 0
      @modules = {}
      @js_modules = {}

      @opts = Slop.parse(:strict => true, :help => true) do
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
      end

      @opts[:sourcepath] << File.expand_path("../cljs", __FILE__)
      @opts[:libpath] << File.expand_path("../js", __FILE__)

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

      main = parse_module(source, file)
      mutator = Shin::Mutator.new
      mutator.mutate(main)

      if opts.ast2?
        puts Oj.dump(main.ast2, :mode => :object, :indent => 2)
        exit 0
      end

      @modules.each do |ns, mod|
        Shin::Translator.new(mod).translate
      end

      if opts.jst?
        puts Oj.dump(main.jst, :mode => :compat, :indent => 2)
        exit 0
      end

      @modules.each do |ns, mod|
        Shin::Generator.new(mod).generate
      end

      if opts.js?
        puts main.code
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
        outdir = opts[:output]
        FileUtils.mkdir_p(outdir)

        @modules.each do |ns, mod|
          File.open("#{outdir}/#{ns}.js", "wb") do |f|
            f.write(mod.code)
          end
        end

        @js_modules.each do |ns, path|
          FileUtils.cp(path, "#{outdir}/#{ns}.js")
        end
      end
    end

    def parse_module(source, file = nil)
      compiler_opts = {}
      mod = Module.new
      if file
        mod.file = file
        compiler_opts[:file] = file
      end

      parser = Shin::Parser.new(source, compiler_opts) 
      mod.ast = parser.parse
      mod.source = parser.input

      if opts.check?
        exit 0
      end

      if opts.sexpr?
        mod.ast.each do |node|
          puts node.to_s
        end
        exit 0
      end

      if opts.ast?
        puts Oj.dump(mod.ast, :mode => :object, :indent => 2)
        exit 0
      end

      handle_ns(mod)
      parse_reqs(mod)

      mod
    end

    def parse_reqs(mod)
      mod.requires.each do |req|
        case req[:type]
        when 'require-js'
          name = req[:name]
          cached = @js_modules[name]
          unless cached
            puts "Looking for JS module #{name}"
            path = find_js_module(name)
            if path
              @js_modules[name] = path
            else
              puts "[WARN] Module not found: #{name}" unless path
            end
          end
        when 'require'
          name = req[:name]
          cached = @modules[name]
          unless cached
            puts "Parsing #{name}"
            path = find_module(name)
            parse_module(File.read(path), path)
            throw "Module not found: #{name}" unless path
          end
        end
      end
      nil
    end

    def handle_ns(mod)
      nsdef = mod.ast[0]
      ns = nil
      if nsdef.list?
        matches?(nsdef.inner, "ns :sym :expr*") do |_, name, specs|
          ns = name.value
          specs.each do |spec|
            matches?(spec.inner, ":kw []") do |type, vec|
              list = vec.inner
              until list.empty?
                aka = name = list.first
                throw "invalid spec, expected sym got #{name}" unless name.sym?
                list = list.drop(1)
                if !list.empty? && list.first.kw?('as')
                  list = list.drop(1)
                  aka = list.first
                  list = list.drop(1)
                end

                mod.requires << {
                  :type => type.value,
                  :name => name.value,
                  :aka  => aka.value,
                }
              end
            end or throw "invalid spec #{spec}"
          end
        end or throw "invalid ns def #{nsdef}"
      end
      # get rid of nsdef (don't translate it)
      mod.ast = mod.ast.drop(1)

      ns ||= "anonymous#{fresh}"
      mod.ns = ns

      @modules[ns] = mod

      if mod.ns != 'shin.core'
        mod.requires << {
          :type => 'require',
          :name => 'shin.core',
          :aka => 'shin'
        }
      end
    end

    def fresh
      @seed += 1
    end

    def find_module(ns)
      @opts[:sourcepath].each do |sp|
        tokens = ns.split('.')

        until tokens.size < 1
          slashes = tokens[0..-2]
          dots = [tokens.last]

          while true
            path = "#{[sp].concat(slashes).join("/")}/#{dots.join(".")}.cljs"
            return path if File.exist?(path)

            break if slashes.empty?
            dots.unshift(slashes.last)
            slashes = slashes[0..-2]
          end

          tokens = tokens.drop(1)
        end
      end
      nil
    end

    def find_js_module(ns)
      @opts[:libpath].each do |lp|
        path = "#{lp}/#{ns}.js"
        return path if File.exists?(path)
      end
      nil
    end
  end

  class Module
    attr_accessor :ns
    attr_accessor :source
    attr_accessor :file
    attr_accessor :ast
    attr_accessor :ast2
    attr_accessor :jst
    attr_accessor :out
    attr_accessor :requires
    attr_accessor :code

    def initialize
      @requires = []
    end
  end
end

