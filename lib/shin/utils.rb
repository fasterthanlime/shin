
module Shin
  module LineColumn
    def line_column(p_input, pos)
      input = p_input.dup
      input.seek 0

      line = 1
      col  = 0

      pos.times do
        case input.getc
        when "\n"
          line += 1
          col = 0
        else
          col += 1
        end
      end

      return line, col
    end
  end

  module Snippet
    def snippet(p_input, pos, p_length = 1)
      length = [p_length, 1].max
      input = p_input.dup
      input.seek 0

      line = ""
      pos.times do
        case (char = input.getc).chr
        when "\n"
          line = ""
        else
          line += char
        end
      end

      line_offset = line.length
      until input.eof
        case (char = input.getc).chr
        when "\n"
          break
        else
          line += char
        end
      end

      underline = ""
      line_offset.times do
        underline += " "
      end
      length.times do
        underline += "~"
        break if underline.length >= line.length
      end

      return "#{line}\n#{underline}"
    end
  end

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
      specs = Shin::Parser.new(pattern).parse

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
          puts "Empty list, remaining specs."
          return false
        end
        node = list.first

        case spec
        when Shin::AST::Sequence
          # TODO: match the inside of sequences.
          if spec.class === node then 
            matches << node
            list = list.drop 1
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
            puts "Expected at least #{min_occ} #{type}"
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
        puts "Empty specs, remaining list #{list}"
        return false
      end

      block.call(*matches) if block
      true
    end
  end
end

