
require 'shin/ast'
require 'shin/utils'

module Shin
  class Parser
    include Shin::Utils::LineColumn
    include Shin::Utils::Snippet

    class Error < StandardError; end
    class EOF < Error; end

    attr_reader :input

    LPAREN = '('.freeze; RPAREN = ')'.freeze
    LBRACK = '['.freeze; RBRACK = ']'.freeze
    LBRACE = '{'.freeze; RBRACE = '}'.freeze
    IDENTIFIER_REGEXP = /[A-Za-z\-_\*'\+\/\?!\$&]/

    def self.parse(source)
      Shin::Parser.new(source).parse
    end

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
        node = read_expr
        ser! "Expected S-expression!" unless node
        nodes << node
        skip_ws
      end

      return nodes
    end

    protected

    def read_sequence(sequence_type, ldelim, rdelim)
      skip_ws
      sequence_name = lambda do
        sequence_type.name.split('::').last.downcase
      end

      return nil unless (char = peek_char).chr == ldelim
      skip_char
      skip_ws

      node = sequence_type.new(token)
      skip_ws
      until eof?
        case (char = peek_char.chr)
        when rdelim
          break
        else
          child = read_expr
          if child.nil?
            ser!("Unclosed #{sequence_name[]} literal, expected: '#{rdelim}' got '#{char}'", node.token)
          end
          node.inner << child
          node.token.extend!(pos)
        end

        skip_ws
      end

      unless (char = read_char).chr == rdelim
        ser!("Unclosed #{sequence_name[]} literal, expected: '#{rdelim}' got '#{char}'", node.token)
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
      ser!("Map literal requires even number of forms", node.token) unless node.inner.count % 2 == 0
      node
    end

    def read_expr
      read_identifier || read_list || read_vector || read_map || read_number || read_string || read_keyword || read_object_access
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

    def read_object_access
      skip_ws
      t = token
      type = :call

      return nil unless peek_char.chr == '.'
      skip_char

      if peek_char.chr == '-'
        type = :access
        skip_char
      end

      id = read_identifier
      ser!("Expected identifier after method call operator") unless id

      case type
      when :access
        Shin::AST::FieldAccess.new(t.extend!(pos), id)
      when :call
        Shin::AST::MethodCall.new(t.extend!(pos), id)
      else
        ser!("Invalid object access type: #{type}")
      end
    end

    def read_identifier
      skip_ws
      s = ""
      t = token

      until eof?
        case (char = peek_char).chr
        when IDENTIFIER_REGEXP
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
      t = token

      return nil unless peek_char.chr == ':'
      skip_char

      id = read_identifier
      return nil if id.nil?

      Shin::AST::Keyword.new(t.extend!(pos), id.value)
    end

    def skip_ws
      until eof?
        case (char = peek_char).chr
        when /\s+/
          skip_char
        when /;/
          skip_char
          until eof?
            char = read_char.chr
            break if char == "\n"
          end
        else
          break
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

    def ser!(msg, token = nil)
      start = token ? token.start : pos
      length = token ? token.length : 1

      line, column = line_column(@input, start)
      snippet = snippet(@input, start, length)

      raise "#{msg} at #{file}:#{line}:#{column}\n\n#{snippet}\n\n"
    end

  end
end
