
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

      def to_hash
        res = {:type => self.class.name.split('::').last}
        res[:loc] = loc if loc
        res
      end
    end

    class Program < Node
      attr_reader :body

      def initialize
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
        @id = id
        @params = []
      end

      def to_hash
        super.merge(:id => id, :params => params, :body => body,
                   :rest => nil, :defaults => [], :generator => false, :expression => false)
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

      def to_hash
        super.merge(:body => body)
      end
    end

    class Identifier < Node
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def to_hash
        super.merge(:name => name)
      end
    end

    class ReturnStatement < Node
      attr_reader :argument

      def initialize(argument)
        @argument = argument
      end

      def to_hash
        super.merge(:argument => argument)
      end
    end

    class ExpressionStatement < Node
      attr_reader :expression

      def initialize(expression)
        @expression = expression
      end

      def to_hash
        super.merge(:expression => expression)
      end
    end

    class CallExpression < Node
      attr_reader :callee
      attr_reader :arguments

      def initialize(callee, arguments = [])
        @callee = callee
        @arguments = arguments
      end

      def to_hash
        super.merge(:callee => callee, :arguments => arguments)
      end
    end

    class NewExpression < CallExpression
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

      def to_hash
        super.merge(:object => object, :property => property, :computed => computed)
      end
    end

    class Literal < Node
      attr_reader :value
      attr_reader :raw

      def initialize(value, raw = nil)
        @value = value
        @raw = raw
      end

      def to_hash
        super.merge(:value => value, :raw => raw)
      end
    end

    class ThisExpression < Node
    end

    class ArrayExpression < Node
      attr_reader :elements

      def initialize
        @elements = []
      end

      def to_hash
        super.merge(:elements => elements)
      end
    end

    class IfStatement < Node
      attr_reader :test
      attr_accessor :consequent
      attr_accessor :alternate

      def initialize(test)
        @test = test
      end

      def to_hash
        super.merge(:test => test, :consequent => consequent, :alternate => alternate)
      end
    end

    class VariableDeclaration < Node
      attr_reader :declarations
      attr_accessor :kind

      def initialize(kind = 'var')
        @declarations = []
        @kind = kind
      end

      def to_hash
        super.merge(:declarations => declarations, :kind => kind)
      end
    end

    class VariableDeclarator < Node
      attr_reader :id
      attr_accessor :init

      def initialize(id, init = nil)
        @id = id
        @init = init
      end

      def to_hash
        super.merge(:id => id, :init => init)
      end
    end
  end
end

