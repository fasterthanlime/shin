
require 'shin/jst'
require 'hamster/list'
require 'set'

module Shin
  # Keeps track of things like scoping, context, etc.
  class JstBuilder
    def initialize
      @scopes  = Hamster.list
      @vases   = Hamster.list
      @anchors = Hamster.list
    end

    def with_anchor(anchor)
      old_anchors = @anchors
      @anchors = @anchors.cons(anchor)
      yield
      @anchors = old_anchors
    end

    def with_scope(scope)
      old_scopes = @scopes
      @scopes = @scopes.cons(scope)
      yield
      @scopes = old_scopes
    end

    def into(recipient, mode = :expression, &block)
      vase = Vase.new(recipient, mode)
      old_vases = @vases
      @vases = @vases.cons(vase)
      yield
      @vases = old_vases
      recipient
    end

    def single
      vase = SingleVase.new
      old_vases = @vases
      @vases = @vases.cons(vase)
      yield
      @vases = old_vases
      vase.recipient
    end

    def into!(recipient, mode = :expression, &block)
      self << into(recipient, mode, &block)
    end

    def anchor
      @anchors.head
    end

    def mode
      @vases.head.mode
    end

    def recipient
      @vases.head.into
    end

    def declare(name, aka)
      @scopes.head[name] = aka
    end

    def lookup(name)
      xs = @scopes
      until xs.empty?
        res = xs.head[name]
        return res if res
        xs = xs.tail
      end
      nil
    end

    def << (candidate)
      @vases.head << candidate
    end

    def vase
      @vases.head
    end

    def to_s
      res = ""
      xs = @scopes
      until xs.empty?
        res += "<- #{xs.head} "
        xs = xs.tail
      end
      res
    end
  end

  # Receives expressions or statements, while being aware of the
  # situation: should we return something? (last position in a function)
  # should we be usable as an expression? or are we just a statement
  # in a function somewhere?
  class Vase
    include Shin::JST

    attr_reader :into
    attr_accessor :mode

    VALID_MODES = %i(expression statement return)

    def initialize(into, mode)
      @into = into
      @mode = mode
    end

    def << (candidate)
      case mode
      when :expression
        case candidate
        when ThrowStatement
          # it's okay, there's no going back anyway...
        when Statement
          raise "[expr mode] Expected expression, got statement:\n\n #{Oj.dump(candidate, :mode => :object, :indent => 2)}"
        end
        into << candidate
      when :statement
        stat = case candidate
               when Statement
                 candidate
               else
                 ExpressionStatement.new(candidate)
               end
        into << stat
      when :return
        stat = case candidate
               when Statement
                 candidate
               else
                 ReturnStatement.new(candidate)
               end
        into << stat
      else
        raise "Unknown mode #{@mode}"
      end
    end

    def bind_sym(name, aka)
      raise "Can't bind_sym in no-scope context" if @scopes.empty?
      @scopes.first[name] = aka
    end

    def to_s
      "<){ #{@mode} -> #{@into} }(>"
    end
  end

  class SingleVase
    attr_reader :recipient

    def << (candy)
      if @recipient
        raise "SingleVase already filled!"
      elsif JST::Statement === candy
        raise "SingleVase wants an expr!"
      else
        @recipient = candy
      end
    end

    def mode
      :expression
    end

    def into
      self
    end

    def empty!
      @recipient = nil
    end
  end

  # Keeps track of what symbols are bound, so we can
  # resolve them to their real names later.
  class Scope
    def initialize
      @defs = {}
    end

    def [](x)
      @defs[x]
    end

    def []=(x, v)
      # TODO: investigate...
      # puts "Overwriting #{x} in scope #{self}" if @defs.has_key?(x)
      @defs[x] = v
    end

    def to_s
      inner = @defs.map { |k, v| "#{k} => #{v}" }.join(", ")
      "(#{inner})"
    end
  end

  class NsScope
    def initialize(ns)
      @ns = ns
      @defs = {}
    end

    def []=(x, y)
      @defs[x] = y
    end

    def [](x)
      return "#{@ns}/#{x}" if @defs.include?(x)
      nil
    end

    def form_for(x)
      @defs[x]
    end
  end

  class CompositeScope < Scope
    def initialize
      super
      @referred = []
    end

    def attach!(referred)
      @referred << referred
    end

    def [](x)
      ours = @defs[x]
      return ours if ours

      # more recent requires shadow the others
      @referred.reverse_each do |ref|
        theirs = ref[x]
        return theirs if theirs
      end
      
      nil
    end

    def to_s
      "(CompositeScope with #{@referred.length} referred)"
    end
  end

  # Recursion point
  class Anchor
    attr_reader :bindings
    attr_reader :sentinel

    def initialize(bindings, sentinel)
      raise "Anchor bindings must be a vector" unless Hamster::Vector === bindings
      @bindings = bindings
      @sentinel = sentinel
    end
  end
end

