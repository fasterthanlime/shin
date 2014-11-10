
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
end

