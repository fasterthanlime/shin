
require 'shin/parser'
require 'shin/mutator'
require 'shin/translator'
require 'shin/generator'
require 'shin/utils'

module Shin
  class Compiler
    include Shin::Utils::Matcher

    attr_reader :opts
    attr_reader :modules
    attr_accessor :cache

    def self.compile_file(path)
      Shin::Compiler.new.compile(File.read(path), :file => path)
    end

    def initialize(opts)
      @opts = opts
      @opts[:sourcepath] ||= []
      @opts[:sourcepath] << File.expand_path("../cljs", __FILE__)

      @opts[:libpath] ||= []
      @opts[:libpath] << File.expand_path("../js", __FILE__)

      @js_modules = {}
      @seed = 0

      if opts[:cache]
        @modules = opts[:cache]
      else
        @modules = ModuleCache.new
      end
    end

    def compile(source, file = nil)
      main = parse_module(source, file)

      @modules.each do |ns, mod|
        next if mod.ast2
        Shin::Mutator.new(mod).mutate
      end

      if opts[:ast2]
        puts Oj.dump(main.ast2, :mode => :object, :indent => 2)
        exit 0
      end

      @modules.each do |ns, mod|
        next if mod.jst
        Shin::Translator.new(self, mod).translate
      end

      if opts[:jst]
        puts Oj.dump(main.jst, :mode => :compat, :indent => 2)
        exit 0
      end

      @modules.each do |ns, mod|
        next if mod.code
        Shin::Generator.new(mod).generate
      end

      if opts[:js]
        puts main.code
        exit 0
      end

      if opts[:exec]
        js = JsContext.new
        js.context['print'] = lambda do |_, *args|
          print args.join(" ")
        end
        js.context['println'] = lambda do |_, *args|
          puts args.join(" ")
        end
        js.load(code, :inline => true)
      elsif opts[:output]
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

      return main
    end

    def parse_module(source, file = nil)
      compiler_opts = {}
      mod = Shin::Module.new
      if file
        mod.file = file
        compiler_opts[:file] = file
      end

      parser = Shin::Parser.new(source, compiler_opts)
      mod.source = parser.input
      mod.ast = parser.parse

      if opts[:ast]
        puts Oj.dump(main.ast2, :mode => :object, :indent => 2)
        exit 0
      end

      handle_ns(mod)
      parse_reqs(mod)

      return mod
    end

    def provide_js_module(name)
      ns = name.gsub(/\.js$/, '')
      mod = @modules[ns]
      if mod
        #puts "Compiler: found #{ns}"
        mod.code
      else
        nil
      end
    end

    def parse_reqs(mod)
      mod.requires.each do |req|
        if req[:type].end_with?('-js')
          name = req[:name]
          cached = @js_modules[name]
          unless cached
            # puts "Looking for JS module #{name}"
            path = find_js_module(name)
            if path
              @js_modules[name] = path
            else
              puts "[WARN] JS Module not found: #{name}" unless path
            end
          end
        else
          name = req[:name]
          cached = @modules[name]
          unless cached
            #puts "Parsing #{name}"
            path = find_module(name)
            parse_module(File.read(path), path)
            raise "Module not found: #{name}" unless path
          end
        end
      end
      nil
    end


    def handle_ns(mod)
      nsdef = mod.ast[0]
      ns = nil
      if nsdef && nsdef.list?
        matches?(nsdef.inner, "ns :sym :expr*") do |_, name, specs|
          # get rid of nsdef (don't translate it)
          mod.ast = mod.ast.drop(1)

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
        end
      end

      ns ||= "anonymous#{fresh}"
      mod.ns = ns

      @modules << mod

      if mod.ns != 'shin.core'
        mod.requires << {
          :type => 'use',
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

    def defs
      defs = []
      ast2.each do |node|
        next unless node.list?
        first = node.inner.first
        if first.sym? && first.value.start_with?("def")
          defs << node.inner[1].value
        end
      end
      defs
    end
  end

  class ModuleCache
    def initialize
      @modules = {}
    end

    def <<(mod)
      @modules[mod.ns] = mod
    end

    def [](ns)
      @modules[ns]
    end

    def each(&block)
      @modules.each(&block)
    end
  end
end
