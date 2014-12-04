
require 'shin/ast'
require 'shin/mutator'
require 'shin/utils'
require 'hamster/list'

module Shin
  class Parser
    DEBUG = ENV['PARSER_DEBUG']

    include Shin::Utils::LineColumn
    include Shin::Utils::Snippet
    include Shin::Utils::Mangler
    include Shin::AST

    class Error < StandardError; end
    class EOF < Error; end
    
    attr_reader :input

    NUMBER_RE = /[0-9]+/
    OPEN_MAP = {
      '(' => List,
      '[' => Vector,
      '{' => Map,
    }

    CLOS_REV_MAP = {
      List    => ')',
      Vector  => ']',
      Map     => '}',
      Set     => '}',
      Closure => ')',
    }

    NAMED_ESCAPES = {
      "newline"   => "\n",
      "return"    => "\r",
      "tab"       => "\t",
      "backspace" => "\b",
    }

    ESCAPES = {
      "\\"  => "\\",
      "\""  => "\"",
      "a"   => "\a",
      "b"   => "\b",
      "r"   => "\r",
      "n"   => "\n",
      "s"   => "\s",
      "t"   => "\t",
    }

    def self.parse(source)
      # parse is a no-op if source is not a String.
      # it might be a piece of already-parsed AST.
      return source unless ::String === source
      Shin::Parser.new(source).parse
    end

    def self.parse_file(path)
      Shin::Parser.new(File.read(path), :file => path).parse
    end

    def initialize(input, options = {})
      @options = options.dup

      case
      when input.respond_to?(:each_char)
        @input = input.freeze
      when input.respond_to?(:to_str)
        require 'stringio' unless defined?(StringIO)
        @input = input.to_str.freeze
      else
        raise ArgumentError, "expected an IO or String input stream, but got #{input.inspect}"
      end
    end

    def parse
      nodes = []
      heap  = Hamster.list(nodes)
      state = Hamster.list(:expr)

      @pos = 0
      @input.each_char do |c|
        if DEBUG
          puts "#{c} at #{@pos}\t<- #{state}"
          puts "      \t<- [#{heap.to_a.join(", ")}]"
          puts
        end

        case state.head
        when :expr, :expr_one
          state = state.tail if state.head == :expr_one

          case c
          when ' ', "\t", "\n", ','
            # muffin
          when '@'
            heap = heap.cons(Deref).cons(token).cons([])
            state = state.cons(:close_one).cons(:expr_one)
          when '`'
            heap = heap.cons(SyntaxQuote).cons(token).cons([])
            state = state.cons(:close_one).cons(:expr_one)
          when "'"
            heap = heap.cons(Quote).cons(token).cons([])
            state = state.cons(:close_one).cons(:expr_one)
          when "~"
            heap = heap.cons(Unquote).cons(token).cons([])
            state = state.cons(:close_one).cons(:expr_one)
          when "^"
            heap = heap.cons(MetaData).cons(token).cons([])
            state = state.cons(:close_one).cons(:expr_one)
          when ';'
            state = state.cons(:comment)
          when '#'
            state = state.cons(:sharp)
          when ':'
            heap = heap.cons(token).cons("")
            state = state.cons(:keyword)
          when '"'
            heap = heap.cons(token).cons("")
            state = state.cons(:string)
          when '(', '[', '{'
            heap = heap.cons(OPEN_MAP[c]).cons(token).cons([])
            state = state.cons(:expr)
          when ')', ']', '}'
            state = state.tail # discard :expr
            els  = heap.head; heap = heap.tail
            tok  = heap.head; heap = heap.tail
            type = heap.head; heap = heap.tail

            ex = CLOS_REV_MAP[type]
            unless c === ex
              ser!("Wrong closing delimiter. Expected '#{ex}' got '#{c}'")
            end
            heap.head << type.new(tok.extend!(@pos), Hamster::Vector.new(els))
          when SYM_START_REGEXP
            state = state.cons(:symbol)
            heap = heap.cons(token).cons("")
            redo
          when NUMBER_RE
            state = state.cons(:number)
            heap = heap.cons(token).cons("")
            redo
          when "\\"
            state = state.cons(:named_escape)
            heap = heap.cons(token).cons("")
          else
            ser!("Unexpected char: #{c}")
          end
        when :close_one
          inner = heap.head; heap = heap.tail
          tok   = heap.head; heap = heap.tail
          type  = heap.head; heap = heap.tail

          raise "Internal error" if inner.length != 1
          heap.head << type.new(tok.extend!(@pos), inner[0])
          state = state.tail
          redo
        when :comment
          state = state.tail if c == "\n"
        when :sharp
          state = state.tail
          case c
          when '('
            t = token
            heap = heap.cons(Closure).cons(t).cons([]).cons(List).cons(t).cons([])
            state = state.cons(:close_one).cons(:expr)
          when '{'
            heap = heap.cons(Set).cons(token).cons([])
            state = state.cons(:expr)
          when '"'
            heap = heap.cons(token).cons("")
            state = state.cons(:regexp)
          else
            ser!("Unexpected char after #: #{c}")
          end
        when :named_escape
          case c
          when /[a-z]/
            heap.head << c
          else
            value = heap.head; heap = heap.tail
            tok   = heap.head; heap = heap.tail
            state = state.tail

            real_value = NAMED_ESCAPES[value]
            ser!("Unknown named escape: \\#{value}") unless real_value
            heap.head << String.new(tok.extend!(@pos), real_value)
            redo
          end
        when :escape_sequence
          real_value = ESCAPES[c]
          if real_value
            heap.head << real_value
          else
            heap.head << "\\#{c}"
          end
          state = state.tail
        when :string, :regexp
          case c
          when "\\"
            state = state.cons(:escape_sequence)
          when '"'
            value = heap.head; heap = heap.tail
            tok   = heap.head; heap = heap.tail
            case state.head
            when :string
              heap.head << String.new(tok.extend!(@pos), value)
            when :regexp
              heap.head << RegExp.new(tok.extend!(@pos), value)
            else
              raise "Internal error"
            end
            state = state.tail
          else
            heap.head << c
          end
        when :number
          case c
          when NUMBER_RE
            heap.head << c
          else
            value = heap.head; heap = heap.tail
            tok   = heap.head; heap = heap.tail
            heap.head << Number.new(tok.extend!(@pos), value.to_f)
            state = state.tail
            redo
          end
        when :symbol
          case c
          when SYM_INNER_REGEXP
            heap.head << c
          else
            value = heap.head; heap = heap.tail
            tok   = heap.head; heap = heap.tail
            heap.head << Symbol.new(tok.extend!(@pos), value)
            state = state.tail
            redo
          end
        when :keyword
          case c
          when SYM_INNER_REGEXP
            heap.head << c
          else
            value = heap.head; heap = heap.tail
            tok   = heap.head; heap = heap.tail
            heap.head << Keyword.new(tok.extend!(@pos), value)
            state = state.tail
            redo
          end
        else
          raise "Inconsistent state: #{state.head}"
        end # case state
        @pos += 1
      end # each_char

      case state.head
      when :number
        value = heap.head; heap = heap.tail
        tok   = heap.head; heap = heap.tail
        heap.head << Number.new(tok.extend!(@pos), value.to_f)
      when :keyword
        value = heap.head; heap = heap.tail
        tok   = heap.head; heap = heap.tail
        heap.head << Keyword.new(tok.extend!(@pos), value)
      when :symbol
        value = heap.head; heap = heap.tail
        tok   = heap.head; heap = heap.tail
        heap.head << Symbol.new(tok.extend!(@pos), value)
      end

      if heap.length > 1
        until heap.empty?
          type = heap.head; heap = heap.tail
          if Class === type
            ser!("Unclosed #{type.name.split('::')[0]}")
            break
          end
        end
      end

      nodes.map! do |node|
        tmp = handle_auto_gensym(node)
        desugar_closure(tmp)
      end

      return nodes
    end

    def token
      Token.new(file, @pos)
    end

    def file
      @options[:file] || "<stdin>"
    end

    def ser!(msg, token = nil)
      start = token ? token.start : @pos
      length = token ? token.length : 1

      line, column = line_column(@input, start)
      snippet = snippet(@input, start, length)

      raise Shin::SyntaxError, "#{msg} at #{file}:#{line}:#{column}\n\n#{snippet}\n\n"
    end

    # Post-parsing logic (auto-gensym, etc.)
    # TODO: break out into separate files
    
    ## Auto-gensym

    def handle_auto_gensym(node, trail = [])
      case node
      when Sequence
        _trail = trail + [node]
        inner = node.inner
        index = 0
        inner.each do |child|
          poster_child = handle_auto_gensym(child, _trail)
          inner = inner.set(index, poster_child) if poster_child != child
          index += 1
        end

        if inner == node.inner
          node
        else
          node.class.new(node.token, inner)
        end
      when SyntaxQuote
        candidate = LetCandidate.new(node)
        _trail = trail + [node, candidate]

        inner = handle_auto_gensym(node.inner, _trail)

        if inner != node.inner
          node = SyntaxQuote.new(node.token, inner)
        end

        if candidate.useful?
          candidate.let(node)
        else
          node
        end
      when Symbol
        if node.value.end_with? '#'
          t = node.token
          candidate = nil
          quote = nil
          found = false
          trail.reverse_each do |parent|
            if SyntaxQuote === parent
              found = true
              quote = parent
              break
            end
            candidate = parent
          end

          unless found
            ser!("auto-gensym used outside syntax quote: #{node}", node.token)
          end

          name = node.value[0..-2]
          sym = candidate.lazy_make(name)
          return Unquote.new(t, Symbol.new(t, sym))
        end
        node
      else
        node
      end
    end

    ## Closure desugaring

    def desugar_closure(node)
      case node
      when Sequence
        inner = node.inner
        index = 0
        inner.each do |child|
          poster_child = desugar_closure(child)
          inner = inner.set(index, poster_child) if poster_child != child
          index += 1
        end

        if inner == node.inner
          node
        else
          node.class.new(node.token, inner)
        end
      when SyntaxQuote
        inner = desugar_closure(node.inner)

        if inner == node.inner
          node
        else
          SyntaxQuote.new(node.token, inner)
        end
      when Closure
        t = node.token
        arg_map = {}
        body = desugar_closure_inner(node.inner, arg_map)

        num_args = arg_map.keys.max || 0
        args = Hamster.vector
        (0..num_args).map do |index|
          name = arg_map[index] || "aarg#{Shin::Mutator.fresh_sym}#{index}-"
          args <<= Shin::AST::Symbol.new(t, name)
        end
        arg_vec = Vector.new(t, args)
        List.new(t, Hamster.vector(Symbol.new(t, "fn"), arg_vec, body))
      else
        node
      end
    end

    def desugar_closure_inner(node, arg_map)
      case node
      when Sequence
        inner = node.inner
        index = 0
        inner.each do |child|
          poster_child = desugar_closure_inner(child, arg_map)
          inner = inner.set(index, poster_child) if poster_child != child
          index += 1
        end

        if inner == node.inner
          node
        else
          node.class.new(node.token, inner)
        end
      when Symbol
        if node.value.start_with?('%')
          index = closure_arg_to_index(node)
          name = arg_map[index]
          unless name
            name = arg_map[index] = "aarg#{Shin::Mutator.fresh_sym}#{index}-"
          end
          return Symbol.new(node.token, name)
        end
        node
      when Closure
        ser!("Nested closures are forbidden", node.token)
      else
        node
      end
    end

    def closure_arg_to_index(sym)
      name = sym.value
      case name
      when '%'  then 0
      when '%%' then 1
      else
        num = name[1..-1]
        ser!("Invalid closure argument: #{name}", sym.token) unless num =~ /^[0-9]+$/
        num.to_i - 1
      end
    end


  end

  class LetCandidate
    include Shin::AST

    def initialize(inner)
      @t = inner.token
      @ginseng = Symbol.new(@t, 'gensym')
      @decls_inner = []

      @cache = {}
    end

    def lazy_make(name)
      sym = @cache[name]
      unless sym
        sym = "#{name}#{Shin::Mutator.fresh_sym}"
        @cache[name] = sym
        @decls_inner << Symbol.new(@t, sym)
        @decls_inner << gensym_call(name)
      end
      sym
    end

    def gensym_call(name)
      List.new(@t, Hamster.vector(@ginseng, String.new(@t, name)))
    end

    def let(inner)
      decls = Vector.new(@t, Hamster::Vector.new(@decls_inner))
      let_inner = Hamster.vector(Symbol.new(@t, 'let'), decls, inner)
      List.new(@t, let_inner)
    end

    def to_s
      "LetCandidate(#{@let}, cache = #{@cache})"
    end

    def useful?
      !@decls_inner.empty?
    end

  end

end
