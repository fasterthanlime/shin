
module Shin
  module Utils
    module Snippet
      def snippet(p_input, pos, p_length = 1)
        length = [p_length, 1].max
        input = StringIO.new(p_input.dup)
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
end

