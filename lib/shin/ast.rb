
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
    end

    class Sequence < Node
      attr_accessor :children

      def initialize(token)
        super(token)
        @children = []
      end
    end

    class List < Sequence
    end

    class Vector < Sequence
    end

    class Map < Sequence
    end

    class Number < Node
      attr_accessor :value

      def initialize(token ,value)
        super(token)
        @value = value
      end
    end

    class String < Node
      attr_accessor :value

      def initialize(token ,value)
        super(token)
        @value = value
      end
    end

    class Identifier < Node
      attr_accessor :value

      def initialize(token ,value)
        super(token)
        @value = value
      end
    end
  end
end

