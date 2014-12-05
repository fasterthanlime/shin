
require 'shin/utils'

module Shin
  class NsParser
    DEBUG = ENV['NSPARSER_DEBUG']

    include Shin::Utils::Matcher

    attr_reader :mod
    @@seed = 0

    def initialize(mod)
      @mod = mod
    end

    def parse
      return if mod.ns

      nsdef = mod.ast[0]
      specs = []

      if nsdef && nsdef.list?
        matches = matches?(nsdef.inner, "ns :sym :expr*")
        if matches
          _, name, _specs = matches

          # get rid of nsdef (don't translate it)
          # FIXME: it's probably not good for NsParser to mutate the AST.
          # Maybe translator could be a champ and just ignore it?
          mod.ast = mod.ast.drop(1)
          mod.ns = name.value
          specs = _specs
        end
      end

      add_core_requires(mod)
      specs.each { |spec| translate_spec(spec) }
      parse_defs(mod.ast)

      mod.ns ||= "anonymous#{fresh}"

      debug "Requires for #{mod.slug}:\n#{mod.requires.join("\n")}"
    end

    def translate_spec(spec)
      list = spec.inner
      type = list.first.value rescue nil

      raise "invalid spec" unless type
      valid_directives = %w(use require require-macros refer-clojure)
      unless valid_directives.include? type
        raise "invalid spec type #{type}: expected one of #{valid_directives.join(", ")}"
      end

      if type == 'refer-clojure'
        rest = list.drop(1)
        until rest.empty?
          directive = rest.first
          rest = rest.drop(1)

          raise "expected keyword as refer-clojure directive" unless directive.kw?
          case directive.value
          when "exclude"
            excludes = rest.first
            rest = rest.drop(1)
            raise "expected vector for :exclude directive in refer-clojure" unless excludes.vector?
            core_req = mod.core_require
            excludes.inner.each do |sym|
              raise "expected symbol to exclude, got #{sym}" unless sym.sym?
              core_req.excludes << sym.value
            end
          else
            raise "invalid refer-clojure directive: #{directive}"
          end
        end
        return
      end

      macro = false
      if type == 'require-macros'
        type = 'require'
        macro = true
      end

      list.drop(1).each do |libspec|
        els = case libspec
        when Shin::AST::Sequence
          libspec.inner
        when Shin::AST::Symbol
          [libspec]
        else
          raise "invalid libspec: #{libspec}"
        end

        raise "invalid libspec: shouldn't be empty #{els}" if els.empty?
        raise "expected sym" unless els.first.sym?
        req = Require.new(els.first.value, :macro => macro)
        mod.requires << req
        req.refer = :all if 'use' === type
        els = els.drop(1)

        until els.empty?
          raise "invalid directives in: #{els}" unless els.length.even?

          directive, args = els
          raise "invalid directive: #{directive}" unless directive.kw?
          els = els.drop(2)

          case directive.value
          when 'as'
            raise ":as needs a symbol as arg, not #{args}" unless args.sym?
            req.as = args.value
          when 'refer'
            raise ":refer invalid outside of :require" unless type === 'require'

            case
            when Shin::AST::Sequence === args
              args.inner.each do |arg|
                raise "can only refer symbols: #{arg}" unless arg.sym?
                req.refer << arg.value
              end
            when args.kw?('all')
              req.refer = :all
            else
              raise "invalid refer-arg: #{args}"
            end
          when 'only'
            raise ":only invalid outside of :require" unless type === 'use'

            raise ":only needs a sequence as arg, not #{args}" unless Shin::AST::Sequence === args
            res.refer = []
            args.inner.each do |arg|
              raise "can only refer symbols: #{arg}" unless arg.sym?
              req.refer << arg.value
            end
          when 'refer-macros'
            mreq = Require.new(req.ns, :macro => true)
            mod.requires << mreq
            case
            when Shin::AST::Sequence === args
              args.inner.each do |arg|
                raise "can only refer symbols: #{arg}" unless arg.sym?
                mreq.refer << arg.value
              end
            when args.kw?('all')
              mreq.refer = :all
            else
              raise "invalid refer-macros arg: #{args}"
            end
          else
            raise "Unknown directive: #{directive.value}"
          end
        end 
      end
    end

    def add_core_requires(mod)
      unless mod.core? && !mod.macro?
        mod.requires << Require.new('cljs.core', :refer => :all, :as => 'clojure.core')
      end

      unless mod.core? && mod.macro?
        mod.requires << Require.new('cljs.core', :refer => :all, :as => 'clojure.core', :macro => true)
      end
    end

    ########################
    # Def parsing
    
    DEF_NAMES = ::Set.new %w(def defn defmacro deftype defprotocol)

    def parse_defs(nodes)
      scope = NsScope.new(@mod.slug)

      nodes.each do |node|
        next unless node.list? && !node.inner.empty?
        first = node.inner.first

        if first.sym? && DEF_NAMES.include?(first.value)
          raise Shin::SyntaxError, "Invalid def: #{node}" unless node.inner.length >= 2

          i = 1
          def_sym = node.inner[1]
          while AST::MetaData === def_sym && i < node.inner.length
            i += 1
            def_sym = node.inner[i]
          end
          name = def_sym.value

          scope[name] = node

          # protocols define some methods that are top-level symbols too cf. #70
          if first.value == "defprotocol"
            gather_defprotocol_defs(scope, node.inner.drop(2))
          end
        end
      end

      @mod.scope = scope.freeze
    end

    def gather_defprotocol_defs(scope, decls)
      decls.each do |decl|
        raise "Invalid protocol function decl" unless decl.list?
        first = decl.inner.first
        raise "Invalid protocol function decl" unless first.sym?
        scope[first.value] = decl
      end
    end

    def fresh
      @@seed += 1
    end

    def debug(*args)
      puts("[NSPARSER] #{args.join(" ")}") if DEBUG
    end

  end

  class Require
    attr_accessor :ns
    attr_accessor :refer
    attr_accessor :as
    attr_accessor :js
    attr_accessor :macro
    attr_accessor :excludes

    def initialize(ns, refer: [], as: nil, macro: false)
      @js = false
      if ns.start_with? 'js/'
        # strip leading 'js/'
        ns = ns[3..-1]
        @js = true
      end

      @ns = ns
      @as = as || ns
      @refer = refer
      @macro = macro
      @excludes = Set.new
    end

    def all?
      @refer === :all
    end

    def js?
      @js
    end

    def macro?
      @macro
    end

    def core?
      !macro? && (ns == "cljs.core")
    end

    def slug
      "#{ns}#{macro ? '__macro' : ''}"
    end

    def as_sym
      "#{as}#{macro ? '__macro' : ''}"
    end

    def to_s
      "(:require [#{js ? 'js/' : ''}#{ns} :refer#{macro ? '-macros' : ''} #{refer.inspect} :as #{as}])"
    end
  end
end

