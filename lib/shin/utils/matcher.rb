
require 'shin/parser'

module Shin
  module Utils
    module Matcher
      TYPE_REGEXP = /^([\w]*)(.*)$/
      TYPE_MAP = {
        "expr" => Shin::AST::Node,
        "id"   => Shin::AST::Identifier,
        "vec"  => Shin::AST::Vector,
        "str"  => Shin::AST::String,
        "num"  => Shin::AST::Number,
        "list" => Shin::AST::List,
        "map"  => Shin::AST::Map,
        "kw"   => Shin::AST::Keyword,
      }

      def single_matches?(node, spec)
        case spec
        when :expr
          true
        when :id
          node.is_a?(Shin::AST::Identifier)
        when :str
          node.is_a?(Shin::AST::StringLiteral)
        when :vec
          node.is_a?(Shin::AST::Vector)
        when :map
          node.is_a?(Shin::AST::Map)
        when :list
          node.is_a?(Shin::AST::List)
        end
      end

      def matches?(ast, pattern, &block)
        specs = Shin::Parser.parse(pattern)

        if block && specs.length != block.arity
          raise "Wrong arity for matches?, got #{block.arity}, expected #{specs.length}"
        end

        unless ast.respond_to?(:to_ary)
          ast = [ast]
        end

        list = ast.to_ary
        matches = []

        specs.each do |spec|
          if list.empty?
            return false
          end
          node = list.first

          case spec
          when Shin::AST::Sequence
            if spec.class === node
              if spec.inner.empty? || matches?(node.inner, spec.inner)
                matches << node
                list = list.drop 1
              else
                return false
              end
            else
              return false
            end
          when Shin::AST::Literal, Shin::AST::Identifier
            if spec.class === node && spec.value == node.value
              matches << node
              list = list.drop 1
            else
              return false
            end
          when Shin::AST::Keyword
            type_name, mods = spec.value.match(TYPE_REGEXP).to_a[1..-1]
            type = TYPE_MAP[type_name]
            raise "Invalid pattern type: '#{spec.value}'" if type.nil?

            min_occ = 1
            multi = false
            case mods
            when '?' # 0 or 1
              min_occ = 0
            when '+' # 1 or more
              multi = true
            when '*' # 0 or more
              min_occ = 0
              multi = true
            end

            coll = []
            until list.empty?
              if type === node
                coll << node
                list = list.drop 1
                node = list.first
              else
                break
              end

              break unless multi
            end

            if min_occ > coll.length
              return false
            end

            if multi
              matches << coll
            else
              matches << coll.first
            end
          end
        end

        unless list.empty?
          return false
        end

        block.call(*matches) if block
        true
      end
    end
  end
end

