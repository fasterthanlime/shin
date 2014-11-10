
require 'shin/ast'
require 'shin/utils'

module Shin
  class Parser
    include Shin::LineColumn

    LPAREN = '('.freeze; RPAREN = ')'.freeze
    LBRACK = '['.freeze; RBRACK = ']'.freeze
    LBRACE = '{'.freeze; RBRACE = '}'.freeze

    def self.parse_file(path)
      Shin::Parser.new(File.read(path), :file => path).parse
    end

    def initialize(input, options = {})
      @options = options.dup

      # Lifted from sxp-ruby
      # @see https://github.com/bendiken/sxp-ruby
      case
      when %i(getc ungetc eof seek).all? { |x| input.respond_to? x }
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
      nodes = []

      skip_ws

      until eof?
        nodes << read_list
        skip_ws
      end

      if nodes.empty?
        ser! "Expected S-expression"
      end

      return nodes
    end

    protected

    def read_sequence(sequence_type, ldelim, rdelim)
      skip_ws

      return nil unless (char = peek_char).chr == ldelim
      skip_char
      skip_ws

      node = sequence_type.new(token)
      until eof?
        skip_ws

        case (char = peek_char.chr)
        when rdelim
          break
        else
          child = read_expr
          unless child
            ser! "expected expression"
          end
          node.inner << child
        end
      end

      unless (char = read_char).chr == rdelim
        ser! "Unclosed sequence literal, expected: '#{rdelim}' got '#{char}'"
      end

      node.token.extend!(pos)
      node
    end

    def read_list
      read_sequence(Shin::AST::List, LPAREN, RPAREN)
    end

    def read_vector
      read_sequence(Shin::AST::Vector, LBRACK, RBRACK)
    end

    def read_map
      node = read_sequence(Shin::AST::Map, LBRACE, RBRACE)
      return nil unless node
      ser!("Map literal requires even number of forms") unless node.inner.count % 2 == 0
      node
    end

    def read_expr
      read_identifier || read_list || read_vector || read_map || read_number || read_string || read_keyword
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
        when /[A-Za-z\-_\*']/
          s += char
          skip_char
        else
          break
        end
      end

      return nil if s.empty?
      Shin::AST::Identifier.new(t.extend!(pos), s)
    end

    def read_keyword
      skip_ws

      return nil unless peek_char.chr == ':'
      skip_char

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
      Shin::AST::Keyword.new(t.extend!(pos), s)
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
