
require 'shin/jst'
require 'shin/utils/hamster'
require 'hamster/deque'

module Shin
  # Keeps track of things like scoping, context, etc.
  class JstBuilder
    include Shin::Utils::Hamster

    def initialize
      @scopes = Hamster.deque
      @trail = Hamster.deque
    end

    def with_scope(scope, &block)
      old_scopes = @scopes

      begin
        @scopes = @scopes.unshift(scope)
        block.call
      ensure
        @scopes = old_scopes
      end
    end

    REQUIRED_VASE_ARGS = %i(into mode)

    def with_vase(opts, &block)
      old_trail = @trail

      vase = case opts
             when Vase
               opts
             else
               raise unless REQUIRED_VASE_ARGS.all? { |x| opts.has_key?(x) }
               Vase.new(opts[:into], opts[:mode])
             end

      begin
        @trail = @trail.unshift(vase)
        block.call
      ensure
        @trail = old_trail
      end
    end

    def lookup(name)
      walk_deque(@scopes) do |scope|
        res = scope[name]
        return res if res
      end
      nil
    end

    def << (candidate)
      raise "Trying to << into empty-trail builder" if @trail.empty?
      @trail.first << candidate
    end

    def to_s
      res = ""
      walk_deque(@scopes) do |scope|
        res += "<- #{scope} "
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
    attr_reader :mode

    VALID_MODES = %i(expression statement return)

    def initialize(into, mode)
      raise unless VALID_MODES.include?(mode)

      raise "Invalid recipient in vase, should respond to :<<" unless into.respond_to?(:<<)
      @into = into
      @mode = mode
    end

    def << (candidate)
      case mode
      when :expression
        if Statement === candidate
          raise "Expected expression, got statement:\n\n #{candidate}"
        end
        into << candidate
      when :statement
        stat = case candidate
               when Statement
                 # all good
               else
                 ExpressionStatement.new(candidate)
               end
        into.body << stat
      when :return
        stat = case candidate
               when ReturnStatement
                 # all good
               else
                 ReturnStatement.new(candidate)
               end
        into.body << stat
      end
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
      @defs[x] = v
    end

    def to_s
      inner = @defs.map { |k, v| "#{k} => #{v}" }.join(", ")
      "(#{inner})"
    end
  end
end

