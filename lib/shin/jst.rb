
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
    end

    module Function
      attr_reader :id
      attr_reader :params
      attr_accessor :body

      def initialize(id = nil)
        @type = "Function"
        @id = id
        @params = []
        @body = nil
        @rest = nil
        @defaults = []
        @generator = false
        @expression = false
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
        @type = "AssignmentExpression"
        @left = left
        @right = right
        @operator = operator
      end
    end

    class BreakStatement < Node
      def initialize
        @type = "BreakStatement"
      end
    end

    class ContinueStatement < Node
      def initialize
        @type = "ContinueStatement"
      end
    end

    class BlockStatement < Node
      attr_reader :body

      def initialize
        @type = "BlockStatement"
        @body = []
      end
    end

    class Identifier < Node
      attr_reader :name

      def initialize(name)
        @type = "Identifier"
        @name = name
      end
    end

    class ReturnStatement < Node
      attr_reader :argument

      def initialize(argument)
        @type = "ReturnStatement"
        @argument = argument
      end
    end

    class ExpressionStatement < Node
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
        @type = "CallExpression"
        @callee = callee
        @arguments = arguments
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
    end

    class ObjectExpression < Node
      attr_reader :properties

      def initialize(properties = [])
        @type = "ObjectExpression"
        @properties = properties
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

    class WhileStatement < Node
      attr_reader :test
      attr_accessor :body

      def initialize(test)
        @type = "WhileStatement"
        @test = test
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

    class IfStatement < Node
      attr_reader :test
      attr_accessor :consequent
      attr_accessor :alternate

      def initialize(test)
        @type = "IfStatement"
        @test = test
        @consequent = nil
        @alternate = nil
      end
    end

    class VariableDeclaration < Node
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
  end
end

