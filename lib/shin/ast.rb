
require 'hamster/vector'
require 'shin/utils/mimic'

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

      def self.dummy
        Token.new("<dummy>", 0)
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
        raise "Expected token, got #{token}" unless Token === token
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
        inner.each do |child|
          raise "Non-node in AST: #{child}" unless Node === child
        end

        @inner = inner
      end
    end

    class List < Sequence
      def list?
        true
      end

      def to_s
        if ENV['PRETTY_SEXP']
          "\n(#{inner.map(&:to_s).join("\n")})".split("\n").map do |x|
            "  " + x
          end.join("\n")
        else
          "(#{inner.map(&:to_s).join(" ")})"
        end
      end

      # ClojureScript protocols

      include Shin::Utils::Mimic

      implement :IList

      implement :ASeq
      implement :ISeq do
        defn '-first' do |s|
          unwrap(inner.first)
        end

        defn '-rest' do |s|
          List.new(token, inner.drop(1))
        end
      end

      implement :INext do
        defn '-next' do |s|
          (inner.count > 1) ? List.new(token, inner.drop(1)) : nil
        end
      end

      implement :IStack do
        defn '-peek' do |s|
          unwrap(inner.first)
        end

        defn '-pop' do |s|
          List.new(token, inner.drop(1))
        end
      end

      implement :ICollection do
        defn '-conj' do |s, o|
          List.new(token, inner.unshift(wrap(o)))
        end
      end

      implement :ISequential
      implement :IEquiv do
        defn '-equiv' do |s, other|
          case other
          when V8::Object
            eq = other[method_sym('-equiv', 2)]
            if eq
              eq.methodcall(other, other, self)
            else
              false
            end
          when List, Vector
            inner == other.inner
          else
            false
          end
        end
      end

      implement :ISeqable do
        defn '-seq' do |s|
          (inner.empty?) ? nil : self
        end
      end

      implement :ICounted do
        defn '-count' do |s|
          inner.count
        end
      end

      implement :IReduce do
        defn '-reduce' do |s, f|
          case inner.length
          when 0
            f.call
          when 1
            inner[1]
          else
            a = unwrap(inner[0])
            b = unwrap(inner[1])
            zero = f.call(a, b)
            invoke('-rest').invoke('-rest').invoke('-reduce', f, zero)
          end
        end
        defn '-reduce' do |s, f, start|
          case inner.length
          when 0
            start
          else
            a = start
            xs = inner
            until xs.empty?
              b = unwrap(xs.first)
              a = f.call(a, b)
              xs = xs.drop(1)
            end
            a
          end
        end
      end

      implement :IPrintable do
        defn '-pr-str' do |s|
          "(#{inner.map { |x| pr_str(x) }.join(" ")})"
        end
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
      def to_s
        "#\"#{value.to_s}\""
      end
    end

    class Symbol < Node
      attr_reader :value

      def initialize(token, value)
        super(token)
        @value = value
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
        @value = value
      end

      def kw?(value = nil)
        return true if value.nil?
        @value == value
      end

      def to_s
        ":#{value}"
      end

      # ClojureScript protocols

      include Shin::Utils::Mimic

      implement :IKeyword
      
      implement :INamed do
        defn '-name' do |s|
          value
        end
      end

      implement :IPrintable do
        defn '-pr-str' do |s|
          to_s
        end
      end

      implement :IEquiv do
        defn '-equiv' do |s, other|
          case other
          when V8::Object
            eq = other[method_sym('-equiv', 2)]
            if eq
              eq.methodcall(other, other, self)
            else
              false
            end
          when Keyword
            value == other.value
          else
            false
          end
        end
      end

      implement :IFn do
        defn '-invoke' do |s, coll|
          raise "invoke ?"
        end
      end

      implement :IHash do
        defn '-hash' do |s|
          raise "stub"
        end
      end

    end

    class MetaData < Node
      attr_reader :inner

      def initialize(token, inner)
        super(token)
        @inner = inner
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

