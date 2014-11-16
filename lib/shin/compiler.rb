
require 'shin/parser'
require 'shin/mutator'
require 'shin/translator'
require 'shin/generator'
require 'shin/utils'

module Shin
  class Compiler
    include Shin::Utils::Matcher
    def self.compile_file(path)
      Shin::Compiler.new.compile(File.read(path), :file => path)
    end

    def initialize(opts)
      @opts = opts
      @opts[:sourcepath] ||= []
      @opts[:sourcepath] << File.expand_path("../cljs", __FILE__)

      @opts[:libpath] ||= []
      @opts[:libpath] << File.expand_path("../js", __FILE__)

      @modules = {}
      @js_modules = {}
      @seed = 0
    end

    def compile(source, file = nil)
      main = parse_module(source, file)
      mutator = Shin::Mutator.new
      mutator.mutate(main)

      @modules.each do |ns, mod|
        Shin::Translator.new(mod).translate
      end

      @modules.each do |ns, mod|
        Shin::Generator.new(mod).generate
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

      handle_ns(mod)
      parse_reqs(mod)

      mutator = Shin::Mutator.new
      mutator.mutate(mod)

      Shin::Translator.new(mod).translate

      generator = Shin::Generator.new(mod)
      generator.generate

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
        case req[:type]
        when 'require-js'
          name = req[:name]
          cached = @js_modules[name]
          unless cached
            # puts "Looking for JS module #{name}"
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
            #puts "Parsing #{name}"
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
