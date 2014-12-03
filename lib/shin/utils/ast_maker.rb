require 'shin/ast'
require 'hamster/vector'
require 'hamster/hash'

module Shin
  module Utils
    module AstMaker
      def sample_token
        Shin::AST::Token.new("dummy", 42)
      end

      def sym(name)
        Shin::AST::Symbol.new(sample_token, name)
      end

      def kw(name)
        Shin::AST::Keyword.new(sample_token, name)
      end

      def literal(value)
        Shin::AST::Literal.new(sample_token, value)
      end

      def sample_kw
        kw("neverland")
      end

      def sample_sym
        sym("oreilly")
      end

      def sample_list
        inner = Hamster.vector(sym("lloyd"), sym("franken"), sym("algae"))
        Shin::AST::List.new(sample_token, inner)
      end

      def sample_vec
        inner = Hamster.vector(kw("these"), kw("arent"), kw("spartae"))
        Shin::AST::Vector.new(sample_token, inner)
      end

      def numeric_list
        inner = Hamster.vector()
        (1..6).each do |n|
          inner <<= Shin::AST::Literal.new(sample_token, n)
        end
        Shin::AST::List.new(sample_token, inner)
      end

      def numeric_vec
        inner = Hamster.vector()
        (1..6).reverse_each do |n|
          inner <<= Shin::AST::Literal.new(sample_token, n)
        end
        Shin::AST::Vector.new(sample_token, inner)
      end

      def empty_map
        Shin::AST::Map.new(sample_token)
      end

      def sample_map
        h = Hamster.hash([[kw("a"), kw("A")],
                          [kw("b"), kw("B")],
                          [kw("c"), kw("C")]])
        Shin::AST::Map.from_hash(sample_token, h)
      end
    end
  end
end
