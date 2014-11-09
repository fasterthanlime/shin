
require 'shin/ast'
require 'shin/utils'

module Shin
  class Parser
    include Shin::LineColumn

    def initialize(input, options = {})
      @options = options.dup

      # Lifted from sxp-ruby
      # @see https://github.com/bendiken/sxp-ruby
      case
      when %i(getc ungetc eof).all? { |x| input.respond_to? x }
        @input = input
      when input.respond_to?(:to_str)
        require 'stringio' unless defined?(StringIO)
        # NOTE: StringIO#ungetc mutates the string, so we use #dup to take a copy.
        @input = StringIO.new(input.to_str.dup)
        @input.set_encoding('UTF-8') if @input.respond_to?(:set_encoding)
      else
        raise ArgumentError, "expected an IO or String input stream, but got #{input.inspect}"
      end
    end

    def parse
      tree = read_list
      unless tree
        ser! "Expected list"
      end

      return tree
    end

    protected

    def read_list
      skip_ws

      return nil unless (char = peek_char).chr == '('
      skip_char
      skip_ws

      node = Shin::AST::List.new(token)
      until eof?
        skip_ws

        case (char = peek_char.chr)
        when ')'
          skip_char; break
        else
          child = read_expr
          unless child
            ser! "expected expression"
          end
          node.children << child
        end
      end

      node.token.extend!(pos)
      node
    end

    def read_expr
      read_list || read_number || read_string || read_identifier
    end

    def read_number
      skip_ws
      s = ""
      t = token

      until eof?
        case (char = peek_char).chr
        when /[0-9]/
          s << char
          skip_char
        else
          break
        end
      end

      return nil if s.empty?
      Shin::AST::Number.new(t.extend!(pos), s.to_f)
    end

    def read_string
      skip_ws
      s = ""
      t = token

      return nil unless peek_char.chr == '"'
      skip_char

      until eof?
        case (char = read_char).chr
        when '"'
          break
        else
          s += char
        end
      end

      return nil if s.empty?
      Shin::AST::String.new(t.extend!(pos), s)
    end

    def read_identifier
      skip_ws
      s = ""
      t = token

      until eof?
        case (char = peek_char).chr
        when /[A-Za-z\-_\*]/
          s += char
          skip_char
        else
          break
        end
      end

      return nil if s.empty?
      Shin::AST::Identifier.new(t.extend!(pos), s)
    end

    def skip_ws
      until eof?
        case (char = peek_char).chr
        when /\s+/ then skip_char
        else break
        end
      end
    end

    def token
      Shin::AST::Token.new(file, pos)
    end

    def file
      @options[:file] || "<stdin>"
    end

    def skip_line
      loop do
        break if eof? || read_char.chr == $/
      end
    end

    def read_chars(count = 1)
      buffer = ''
      count.times { buffer << read_char.chr }
      buffer
    end

    def read_char
      char = @input.getc
      raise EOF, 'unexpected end of input' if char.nil?
      char
    end

    alias_method :skip_char, :read_char

    def peek_char
      char = @input.getc
      @input.ungetc(char) unless char.nil?
      char
    end

    def unread(string)
      string.reverse.each_char {|c| @input.ungetc(c)}
    end

    def pos
      @input.pos
    end

    def eof?
      @input.eof?
    end

    def ser!(msg)
      line, column = line_column(@input, pos)
      raise "#{msg} at #{file}:#{line}:#{column}"
    end

  end
end
