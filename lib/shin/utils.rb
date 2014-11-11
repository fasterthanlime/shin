
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

    def matches?(ast, specs, &block)
      if block && specs.length != block.arity
        raise "Wrong arity for matches?, got #{block.arity}, expected #{specs.length}"
      end

      args = []

      if ast.respond_to?(:to_ary)
        list = ast.to_ary
        specs.each do |spec|
          if list.empty?
            puts "Empty list, remaining specs."
            return false
          end
          node = list.first

          case
          when spec.respond_to?(:to_hash)
            raise "matches? can't handle hashes right now."
          when spec.respond_to?(:to_ary)
            arr = spec.to_ary
            coll = []
            until list.empty?
              if single_matches?(node, arr[0])
                coll << node
              else
                puts "#{node} != spec #{arr[0]}"
                return false
              end
              list = list[1..-1]
              node = list.first
            end
            args << coll
          when Symbol === spec
            if single_matches?(node, spec)
              args << node
              list = list[1..-1]
            else
              puts "#{node} != spec #{spec}"
              return false
            end
          end
        end
      else
        if specs.length != 1
          puts "Single AST node but multiple specs"
          return false
        end
        node = ast
        spec = specs.first

        if single_matches?(node, spec)
          args << node
        else
          puts "#{node} != spec #{spec}"
          return false
        end
      end
      block.call(*args) if block
      true
    end
  end
end

