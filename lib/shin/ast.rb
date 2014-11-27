
require 'hamster/vector'

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

      def to_s
        "<#{@file} at #{@start}>"
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

      def meta?(value = nil)
        false
      end
      
      def sym?(value = nil)
        false
      end

      def kw?(value = nil)
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

      def initialize(token, inner = Hamster.vector)
        super(token)
        raise "Sequence needs immutable vector" unless Hamster::Vector === inner
        @inner = inner
        self.freeze
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

      def initialize(token, value)
        super(token)
        @value = value.freeze
        self.freeze
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
      def to_s
        "#\"#{value.to_s}\""
      end
    end

    class Symbol < Node
      attr_reader :value

      def initialize(token, value)
        super(token)
        @value = value.freeze
        self.freeze
      end

      def sym?(value = nil)
        return true if value.nil?
        @value == value
      end

      def to_s
        value
      end
    end

    class Keyword < Node
      attr_reader :value

      def initialize(token, value)
        super(token)
        @value = value.freeze
        self.freeze
      end

      def kw?(value = nil)
        return true if value.nil?
        @value == value
      end

      def to_s
        ":#{value}"
      end
    end

    class MetaData < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
        self.freeze
      end

      def meta?(value = nil)
        return true unless value
        inner && inner.kw?(value)
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
        self.freeze
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
        self.freeze
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
        self.freeze
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
        self.freeze
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
        self.freeze
      end

      def to_s
        "@#{inner}"
      end
    end
  end
end

