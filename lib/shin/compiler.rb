
require 'benchmark'
require 'shin/parser'
require 'shin/ns_parser'
require 'shin/mutator'
require 'shin/translator'
require 'shin/generator'
require 'shin/utils'

module Shin
  class Compiler
    DEBUG = ENV['COMPILER_DEBUG']

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
      main = nil
      parse_time = Benchmark.measure do
        main = parse_module(source, additionals)
      end
      puts "Parsing\t#{parse_time}" if @opts[:profile]

      all_mods = collect_deps(main)
      mutate_skips = []
      mutate_time = Benchmark.measure do
        all_mods.each do |slug, mod|
          if mod.ast2
            mutate_skips << slug
            next
          end
          Shin::Mutator.new(self, mod).mutate
        end
      end
      puts "Mutating\t#{mutate_time} (skips: #{mutate_skips.join(" ")})" if @opts[:profile]

      if opts[:ast2]
        puts main.ast2.join("\n")
        exit 0
      end

      translate_skips = []
      translate_time = Benchmark.measure do
        all_mods.each do |slug, mod|
          if mod.jst
            translate_skips << slug
            next
          end
          Shin::Translator.new(self, mod).translate
        end
      end
      puts "Translating\t#{translate_time} (skips: #{translate_skips.join(" ")})" if @opts[:profile]

      if opts[:jst]
        puts Oj.dump(main.jst, :mode => :object, :indent => 2)
        exit 0
      end

      generate_skips = []
      generate_time = Benchmark.measure do
        all_mods.each do |slug, mod|
          if mod.code
            generate_skips << slug
            next
          end
          Shin::Generator.new(mod).generate
        end
      end
      puts "Generation\t#{generate_time} (skips: #{generate_skips.join(" ")})" if @opts[:profile]

      if opts[:js]
        puts main.code
        exit 0
      end

      if opts[:exec]
        js = JsContext.new
        js.providers << self
        js.context['print'] = lambda do |_, *args|
          print args.join(" ")
        end
        js.context['println'] = lambda do |_, *args|
          puts args.join(" ")
        end
        js.load(main.code, :inline => true)
      elsif opts[:output]
        outdir = opts[:output]
        FileUtils.mkdir_p(outdir)

        all_mods.each do |slug, mod|
          next if mod.macro?
          File.open("#{outdir}/#{mod.ns}.js", "wb") do |f|
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

      if additionals[:macro]
        mod.macro = true
      end

      parser = Shin::Parser.new(source, compiler_opts)
      mod.source = parser.input
      mod.ast = parser.parse

      if opts[:ast]
        puts mod.ast.join("\n")
        exit 0
      end

      Shin::NsParser.new(mod).parse
      @modules << mod

      if macros = additionals[:macros]
        macros_source = "(ns #{mod.ns})\n#{macros}"
        parse_module(macros_source, :macro => true)
        mod.requires << Require.new(mod.ns, :macro => true, :refer => :all)
      end

      parse_reqs(mod)

      return mod
    end

    def provide_js_module(name)
      ns = name.gsub(/\.js$/, '')
      mod = @modules.lookup(ns, :macro => false)
      if mod
        #puts "Compiler: found #{ns}"
        mod.code
      else
        nil
      end
    end

    def parse_reqs(mod)
      mod.requires.each do |req|
        if req.js?
          unless cached = @js_modules[req.ns]
            debug "Looking for JS module #{req.ns}"
            path = find_js_module(req.ns)
            if path
              @js_modules[req.ns] = path
            else
              puts "[WARN] JS Module not found: #{req.ns}" unless path
            end
          end
        else
          unless cached = @modules[req]
            debug "Parsing #{req.slug}"
            path = find_module(req.ns, :macro => req.macro)
            raise "Module not found: #{req.slug}" unless path
            parse_module(File.read(path), :file => path, :macro => req.macro?)
          end
        end
      end
      nil
    end

    def find_module(ns, macro: false)
      ext = macro ? "clj" : "cljs"

      @opts[:sourcepath].each do |sp|
        tokens = ns.split('.')

        until tokens.size < 1
          slashes = tokens[0..-2]
          dots = [tokens.last]

          while true
            path = "#{[sp].concat(slashes).join("/")}/#{dots.join(".")}.#{ext}"
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
      all[mod.slug] = mod

      mod.requires.each do |req|
        next if req.js?
        dep = @modules[req]
        raise "While collecting deps for #{mod.slug}, couldn't find #{req.slug}" unless dep

        unless all[dep.slug]
          collect_deps(dep, all)
        end
      end
      all
    end

    private

    def debug(*args)
      puts("[COMPILER] #{args.join(" ")}") if DEBUG
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

    attr_accessor :mutating
    attr_accessor :macro

    def initialize
      @requires = []
      @macro = false
      @mutating = false
    end

    def core?
      @ns == 'cljs.core'
    end

    def defs
      defs = {}
      # FIXME: oh god this is terrible.
      a = ast2 || ast
    
      a.each do |node|
        next unless node.list?
        first = node.inner.first
        # a non-private def
        if first.sym? && first.value.start_with?("def") && !first.value.end_with?("-")
          raise "Invalid def: #{node}" unless node.inner.length >= 2
          name = node.inner[1].value
          defs[name] = node
        end
      end
      defs
    end

    def macro?
      @macro
    end

    def slug
      "#{ns}#{macro ? '..macro' : ''}"
    end
  end

  class ModuleCache
    def initialize
      @modules = {}
    end

    def <<(mod)
      @modules[mod.slug] = mod
    end

    def [](req)
      raise "ModuleCache expecting Require, got : #{req}" unless Shin::Require === req
      @modules[req.slug]
    end

    def lookup(ns, macro: false)
      @modules["#{ns}#{macro ? '..macro' : ''}"]
    end

    def each(&block)
      @modules.each(&block)
    end
  end
end
