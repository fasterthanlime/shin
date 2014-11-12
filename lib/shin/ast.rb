
module Shin
  module AST
    class Token
      attr_reader :file
      attr_reader :start
      attr_reader :end
      attr_reader :line
      attr_reader :column

      def initialize(file, pos)
        @file = file
        @start = @end = pos
        compute_linecol
      end

      def length
        @end - @start
      end

      def extend!(pos)
        fail unless pos >= @start
        @end = pos
        self
      end

      private

      def compute_linecol
        # stub
      end
    end

    class Node
      attr_reader :token

      def initialize(token)
        @token = token
      end
      
      def identifier?(value = nil)
        false
      end

      def literal?
        false
      end

      def list?
        false
      end
      
      def set?
        false
      end

      def vector?
        false
      end

      def map?
        false
      end
    end

    class Sequence < Node
      attr_accessor :inner

      def initialize(token)
        super(token)
        @inner = []
      end
    end

    class List < Sequence
      def list?
        true
      end

      def to_s
        "(#{inner.map(&:to_s).join(" ")})"
      end
    end

    class Vector < Sequence
      def vector?
        true
      end

      def to_s
        "[#{inner.map(&:to_s).join(" ")}]"
      end
    end

    class Set < Sequence
      def set?
        true
      end

      def to_s
        "\#{#{inner.map(&:to_s).join(" ")}}"
      end
    end

    class Map < Sequence
      def map?
        true
      end

      def to_s
        "{#{inner.map(&:to_s).join(" ")}}"
      end
    end

    class Literal < Node
      attr_accessor :value

      def initialize(token ,value)
        super(token)
        @value = value
      end

      def literal?
        true
      end

      def to_s
        value.inspect
      end
    end

    class Number < Literal
    end

    class String < Literal
    end

    class RegExp < Literal
    end

    class Bool < Literal
    end

    class Nil < Literal
      def initialize(token)
        super(token, nil)
      end
    end

    class Identifier < Node
      attr_accessor :value

      def initialize(token ,value)
        super(token)
        @value = value
      end

      def identifier?(value = nil)
        return true if value.nil?
        @value == value
      end

      def to_s
        value
      end
    end

    class Keyword < Node
      attr_accessor :value

      def initialize(token, value)
        super(token)
        @value = value
      end

      def to_s
        ":#{value}"
      end
    end

    class ObjectAccess < Node
      attr_accessor :id

      def initialize(token, id)
        super(token)
        @id = id
      end
    end

    class MethodCall < ObjectAccess
      def to_s
        ".#{id.value})"
      end
    end

    class FieldAccess < ObjectAccess
      def to_s
        ".-#{id.value})"
      end
    end

    class MetaData < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
      end

      def to_s
        "^#{inner}"
      end
    end

    class Closure < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
      end

      def to_s
        "##{inner}"
      end
    end

    class Quote < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
      end

      def to_s
        "'#{inner}"
      end
    end

    class SyntaxQuote < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
      end

      def to_s
        "`#{inner}"
      end
    end

    class Unquote < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
      end

      def to_s
        "~#{inner}"
      end
    end

    class Deref < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
      end

      def to_s
        "@#{inner}"
      end
    end
  end
end

