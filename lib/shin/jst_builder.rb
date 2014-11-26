
require 'shin/jst'
require 'shin/utils/hamster'
require 'hamster/deque'

module Shin
  # Keeps track of things like scoping, context, etc.
  class JstBuilder
    include Shin::Utils::Hamster

    def initialize
      @scopes = Hamster.deque
      @vases = Hamster.deque
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

    def into(recipient, mode = :expression, dest: nil, &block)
      with_vase(:into => recipient, :mode => mode, :dest => dest, &block)
      recipient
    end

    def into!(recipient, mode = :expression, dest: nil, &block)
      self << into(recipient, mode, :dest => dest, &block)
    end

    REQUIRED_VASE_ARGS = %i(into mode)

    def with_vase(opts, &block)
      old_vases = @vases

      vase = case opts
             when Vase
               opts
             else
               raise unless REQUIRED_VASE_ARGS.all? { |x| opts.has_key?(x) }
               Vase.new(opts[:into], opts[:mode], :dest => opts[:dest])
             end

      begin
        @vases = @vases.unshift(vase)
        block.call
      ensure
        @vases = old_vases
      end
    end

    def declare(name, aka)
      raise "Trying to declare #{name} into no-scope builder" if @scopes.empty?
      @scopes.first[name] = aka
    end

    def lookup(name)
      walk_deque(@scopes) do |scope|
        res = scope[name]
        return res if res
      end
      nil
    end

    def << (candidate)
      raise "Trying to << into no-vase builder" if @vases.empty?
      @vases.first << candidate
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

    VALID_MODES = %i(expression statement return assign)

    def initialize(into, mode, dest: nil)
      raise unless VALID_MODES.include?(mode)

      raise "Invalid recipient in vase, should respond to :<<" unless into.respond_to?(:<<)
      @into = into
      @mode = mode

      raise "Need dest for 'assign' mode" if (mode == :assign && dest.nil?)
      @dest = dest
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
                 candidate
               else
                 ExpressionStatement.new(candidate)
               end
        into << stat
      when :return
        stat = case candidate
               when ReturnStatement
                 candidate
               when ThrowStatement
                 into << candidate
                 ReturnStatement.new(Literal.new(nil))
               else
                 ReturnStatement.new(candidate)
               end
        into << stat
      when :assign
        if Statement === candidate
          raise "Expected expression, got statement:\n\n #{candidate}"
        end
        ass = AssignmentExpression.new(@dest, candidate)
        into << ExpressionStatement.new(ass)
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
      raise "Overwriting #{x} in scope #{self}" if @defs.has_key?(x)
      @defs[x] = v
    end

    def to_s
      inner = @defs.map { |k, v| "#{k} => #{v}" }.join(", ")
      "(#{inner})"
    end
  end
end

