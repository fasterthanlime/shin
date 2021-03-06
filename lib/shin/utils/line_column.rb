
module Shin
  module Utils
    module LineColumn
      def line_column(p_input, pos)
        input = StringIO.new(p_input.dup)
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
  end
end

