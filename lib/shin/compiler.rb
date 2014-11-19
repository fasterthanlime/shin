
require 'shin/parser'
require 'shin/ns_parser'
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

      if opts[:cache]
        @modules = opts[:cache]
      else
        @modules = ModuleCache.new
      end
    end

    def compile(source, additionals = {})
      main = parse_module(source, additionals)

      all_mods = collect_deps(main)
      all_mods.each do |ns, mod|
        next if mod.ast2
        Shin::Mutator.new(self, mod).mutate
      end

      if opts[:ast2]
        puts Oj.dump(main.ast2, :mode => :object, :indent => 2)
        exit 0
      end

      all_mods.each do |ns, mod|
        next if mod.jst
        Shin::Translator.new(self, mod).translate
      end

      if opts[:jst]
        puts Oj.dump(main.jst, :mode => :compat, :indent => 2)
        exit 0
      end

      all_mods.each do |ns, mod|
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

        all_mods.each do |ns, mod|
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

    def parse_module(source, additionals = {})
      compiler_opts = {}
      file = additionals[:file]
      mod = Shin::Module.new
      if file
        mod.file = file
        compiler_opts[:file] = file
      end

      macros = additionals[:macros]
      if macros
        mod.macros = parse_module(macros)
        mod.macros.is_macro = true
        puts "Got macros: #{mod.macros.ast.join(" ")}"
      end

      parser = Shin::Parser.new(source, compiler_opts)
      mod.source = parser.input
      mod.ast = parser.parse

      if opts[:ast]
        puts Oj.dump(main.ast2, :mode => :object, :indent => 2)
        exit 0
      end

      Shin::NsParser.new(mod).parse
      @modules << mod
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
            parse_module(File.read(path), :file => path)
            raise "Module not found: #{name}" unless path
          end
        end
      end
      nil
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

    def collect_deps(mod, all = {})
      all[mod.ns] = mod

      mod.requires.each do |req|
        next if req[:type].end_with?("js")
        dep = @modules[req[:name]]

        unless all.include?(dep)
          collect_deps(dep, all)
        end
      end
      all
    end

  end

  class Module
    attr_accessor :ns
    attr_accessor :source
    attr_accessor :file
    attr_accessor :ast
    attr_accessor :ast2
    attr_accessor :jst
    attr_accessor :requires
    attr_accessor :code

    attr_accessor :is_macro
    attr_accessor :macros

    def initialize
      @requires = []
      @is_macro = false
    end

    def defs
      defs = {}
      # FIXME: oh god this is terrible.
      a = ast2 || ast
    
      a.each do |node|
        next unless node.list?
        first = node.inner.first
        if first.sym? && first.value.start_with?("def")
          name = node.inner[1].value
          defs[name] = node
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
