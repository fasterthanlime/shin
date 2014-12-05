
require 'shin/parser'
require 'shin/errors'

module Shin
  module Utils
    module Matcher
      include Shin::AST

      TYPE_REGEXP = /^([\w]*)(.*)$/
      TYPE_MAP = {
        "expr" => Node,
        "sym"  => Symbol,
        "vec"  => Vector,
        "str"  => String,
        "num"  => Number,
        "list" => List,
        "map"  => Map,
        "kw"   => Keyword,
        "meta" => MetaData,
      }

      @@ast_cache = {}

      def matches?(ast, pattern)
        specs = lazy_parse(pattern)

        unless ast.respond_to?(:to_ary)
          ast = [ast]
        end

        list = ast.to_ary
        matches = []

        specs.each do |spec|
          node = list.first

          case spec
          when Sequence
            return false if node.nil?
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
          when Literal, Symbol
            return false if node.nil?
            if spec.class === node && spec.value == node.value
              matches << node
              list = list.drop 1
            else
              return false
            end
          when Keyword
            type_name, mods = spec.value.match(TYPE_REGEXP).to_a[1..-1]
            type = TYPE_MAP[type_name]
            raise PatternError.new("Invalid pattern type: '#{spec.value}'") if type.nil?

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

        if list.empty?
          # matched everything, woo!
          matches
        else
          # didn't match everything.
          nil
        end
      end

      def lazy_parse(pattern)
        @@ast_cache[pattern] ||= Shin::Parser.parse(pattern)
      end
    end
  end
end

