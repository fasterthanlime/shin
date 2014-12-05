
require 'shin/ast'

module Shin
  # JavaScript AST for Shin - based on the Mozilla Parser API, following in the
  # footsteps of escodegen, esprima, acorn.
  # https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
  module JST
    class Position
      attr_reader :line
      attr_reader :column

      def initialize(line, column)
        @type = "Position"
        @line = line
        @column = column
      end
    end

    class SourceLocation
      attr_reader :source
      attr_reader :start
      attr_reader :end

      def initialize(source, _start, _end)
        @type = "SourceLocation"
        @source = source
        @start = _start
        @end = _end
      end
    end

    class Node
      attr_accessor :loc

      def to_s
        "[JST::#{@type}]"
      end
    end

    class Statement < Node
    end

    class Program < Node
      attr_reader :body

      def initialize
        @type = "Program"
        @body = []
      end

      def to_hash
        super.merge(:body => body)
      end

      def << (arg)
        @body << arg
      end
    end

    module Function
      attr_accessor :id
      attr_reader :params
      attr_accessor :body

      def initialize(id = nil)
        @type = "Function"
        @id = id
        @params = []
        @body = BlockStatement.new
        @rest = nil
        @defaults = []
        @generator = false
        @expression = false
      end

      def << (arg)
        @body << arg
      end
    end

    class FunctionDeclaration < Node
      include Function

      def initialize(*args)
        super(*args)
        @type = "FunctionDeclaration"
      end
    end

    class FunctionExpression < Node
      include Function

      def initialize(*args)
        super(*args)
        @type = "FunctionExpression"
      end
    end

    class AssignmentExpression < Node
      attr_reader :left
      attr_reader :right
      attr_reader :operator

      def initialize(left, right, operator = '=')
        raise "Expected JST node, got #{left.inspect}" unless Node === left
        raise "Expected JST node, got #{right.inspect}" unless Node === right
        @type = "AssignmentExpression"
        @left = left
        @right = right
        @operator = operator
      end
    end

    class BreakStatement < Statement
      def initialize
        @type = "BreakStatement"
      end
    end

    class ContinueStatement < Statement
      def initialize
        @type = "ContinueStatement"
      end
    end

    class BlockStatement < Statement
      attr_reader :body

      def initialize
        @type = "BlockStatement"
        @body = []
      end

      def << (arg)
        raise "[blockstatement] Expected statement, got #{arg}" unless Statement === arg
        @body << arg
      end
    end

    class Identifier < Node
      attr_reader :name

      def initialize(name)
        @type = "Identifier"
        @name = name
      end
    end

    class ReturnStatement < Statement
      attr_reader :argument

      def initialize(argument)
        raise "Can't initialize ReturnStatement with null" if argument.nil?
        @type = "ReturnStatement"
        @argument = argument
      end
    end

    class ExpressionStatement < Statement
      attr_reader :expression

      def initialize(expression)
        @type = "ExpressionStatement"
        @expression = expression
      end
    end

    class CallExpression < Node
      attr_reader :callee
      attr_reader :arguments

      def initialize(callee, arguments = [])
        raise "Expected JST node, got #{callee.inspect}" unless Node === callee
        raise "CallExpression requires an array of arguments or nil" unless Array === arguments
        @type = "CallExpression"
        @callee = callee
        @arguments = arguments
      end

      def << (arg)
        @arguments << arg
      end
    end

    class NewExpression < CallExpression
      def initialize(callee, arguments = [])
        super(callee, arguments)
        @type = "NewExpression"
      end
    end

    class MemberExpression < Node
      attr_reader :object
      attr_reader :property
      attr_reader :computed

      def initialize(object, property, computed)
        raise "Expected JST node, got #{object.inspect}" unless Node === object
        raise "Expected JST node, got #{property.inspect}" unless Node === property
        @type = "MemberExpression"
        @object = object
        @property = property
        @computed = computed
      end
    end

    class Literal < Node
      attr_reader :value
      attr_reader :raw

      def initialize(value, raw = nil)
        @type = "Literal"
        @value = value
        @raw = raw
      end
    end

    class ThisExpression < Node

      def initialize
        @type = "ThisExpression"
      end
    end

    class ArrayExpression < Node
      attr_reader :elements

      def initialize(elements = [])
        @type = "ArrayExpression"
        @elements = elements
      end

      def << (arg)
        @elements << arg
      end
    end

    class Property < Node
      attr_reader :key
      attr_reader :value

      def initialize(key, value)
        @type = "Property"
        @key = key
        @value = value
      end
    end

    class ObjectExpression < Node
      attr_reader :properties

      def initialize(properties = [])
        @type = "ObjectExpression"
        @properties = properties
      end

      def << (arg)
        raise "Object expression expected property, got #{arg.inspect}" unless Property === arg
        @elements << arg
      end
    end

    class WhileStatement < Statement
      attr_reader :test
      attr_accessor :body

      def initialize(test)
        @type = "WhileStatement"
        @test = test
        @body = BlockStatement.new
      end

      def << (stat)
        @body << stat
      end
    end

    class ConditionalExpression < Node
      attr_reader :test
      attr_accessor :consequent
      attr_accessor :alternate

      def initialize(test)
        @type = "ConditionalExpression"
        @test = test
        @consequent = nil
        @alternate = nil
      end
    end

    class IfStatement < Statement
      attr_reader :test
      attr_accessor :consequent
      attr_accessor :alternate

      def initialize(test)
        @type = "IfStatement"
        @test = test
        @consequent = BlockStatement.new
        @alternate = nil
      end
    end

    class SwitchCase < Node
      attr_reader :test
      attr_reader :consequent

      def initialize(test)
        @type = "SwitchCase"
        @test = test
        @consequent = []
      end

      def << (arg)
        raise "Expected Statement" unless Statement === arg
        @consequent << arg
      end
    end

    class SwitchStatement < Statement
      attr_reader :discriminant
      attr_reader :cases

      def initialize(discriminant, cases = [])
        @type = "SwitchStatement"
        @discriminant = discriminant
        @cases = []
        cases.each { |x| self << x } unless cases.empty?
      end

      def << (_case)
        raise "Expected case, got #{_case}" unless SwitchCase === _case
        @cases << _case
      end
    end

    class VariableDeclaration < Statement
      attr_reader :declarations
      attr_accessor :kind

      def initialize(kind = 'var')
        @type = "VariableDeclaration"
        @declarations = []
        @kind = kind
      end
    end

    class VariableDeclarator < Node
      attr_reader :id
      attr_accessor :init

      def initialize(id, init = nil)
        @type = "VariableDeclarator"
        @id = id
        @init = init
      end
    end

    class BinaryExpression < Node
      attr_reader :operator
      attr_reader :left
      attr_reader :right

      def initialize(operator, left, right)
        @type = "BinaryExpression"
        @operator = operator
        @left = left
        @right = right
      end
    end

    class UnaryExpression < Node
      attr_reader :operator
      attr_reader :argument

      def initialize(operator, argument)
        @type = "UnaryExpression"
        @operator = operator
        @argument = argument
      end
    end

    class ThrowStatement < Statement
      attr_reader :argument

      def initialize(argument)
        @type = "ThrowStatement"
        @argument = argument
      end
    end

    class TryStatement < Statement
      attr_reader :block
      attr_reader :handlers
      attr_accessor :finalizer

      def initialize
        @type = "TryStatement"
        @block = BlockStatement.new
        @handlers = []
        @finalizer = nil
      end

      def << (stat)
        @block << stat
      end
    end

    class CatchClause < Node
      attr_reader :param
      attr_reader :body

      def initialize(param)
        @type = "CatchClause"
        @param = param
        @body = BlockStatement.new
      end

      def << (stat)
        @body << stat
      end
    end
  end
end

