
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
        @line = line
        @column = column
      end
    end

    class SourceLocation
      attr_reader :source
      attr_reader :start
      attr_reader :end

      def initialize(source, _start, _end)
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
        @body = []
      end
    end

    module Function
      attr_reader :id
      attr_reader :params
      attr_accessor :body

      def initialize(id)
        @id = id
        @params = []
      end
    end

    class FunctionDeclaration < Node
      include Function
    end

    class FunctionExpression < Node
      include Function
    end

    class BlockStatement < Node
      attr_reader :body

      def initialize
        @body = []
      end
    end

    class Identifier < Node
      attr_reader :id

      def initialize(id)
        @id = id
      end
    end

    class ReturnStatement < Node
      attr_reader :argument

      def initialize(argument)
        @argument = argument
      end
    end

    class ExpressionStatement < Node
      attr_reader :expression

      def initialize(expression)
        @expression = expression
      end
    end

    class CallExpression < Node
      attr_reader :callee
      attr_reader :arguments

      def initialize(callee)
        @callee = callee
        @arguments = []
      end
    end

    class MemberExpression < Node
      attr_reader :object
      attr_reader :property
      attr_reader :computed

      def initialize(object, property, computed)
        @object = object
        @property = property
        @computed = computed
      end
    end

    class Literal < Node
      attr_reader :value

      def initialize(value)
        @value = value
      end
    end
  end
end

