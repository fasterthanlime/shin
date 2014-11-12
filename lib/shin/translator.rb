
require 'shin/jst'
require 'shin/ast'
require 'shin/utils'

module Shin
  # Converts Shin AST to JST
  class Translator
    include Shin::Utils::LineColumn
    include Shin::Utils::Snippet
    include Shin::Utils::Matcher
    include Shin::JST

    def initialize(p_input, options)
      @input = p_input.dup
      @options = options
    end

    def translate(ast)
      requires = %w(exports shin mori)

      program = Program.new
      load_shim = FunctionExpression.new(nil)
      load_shim.params << make_ident('root');
      load_shim.params << make_ident('factory')
      load_shim.body = BlockStatement.new
      define_call = CallExpression.new(make_ident('define'))
      require_arr = ArrayExpression.new
      requires.each do |req|
        require_arr.elements << make_literal(req)
      end
      define_call.arguments << require_arr
      define_call.arguments << make_ident('factory')
      load_shim.body.body << ExpressionStatement.new(define_call)

      factory = FunctionExpression.new(nil)
      requires.each do |req|
        factory.params << make_ident(req)
      end
      factory.body = BlockStatement.new

      shim_call = CallExpression.new(load_shim)
      shim_call.arguments << ThisExpression.new
      shim_call.arguments << factory
      program.body << ExpressionStatement.new(shim_call)

      body = factory.body.body
      shin_init = MemberExpression.new(make_ident('shin'), make_ident('init'), false)
      init_call = CallExpression.new(shin_init)
      init_call.arguments << make_ident('this')
      init_call.arguments << make_literal('shin_module')
      body << ExpressionStatement.new(init_call)

      ast.each do |node|
        case
        when matches?(node, "(defn :expr*)")
          # it's a function!
          body << translate_defn(node.inner.drop 1)
        when matches?(node, ":expr")
          # any expression is a statement, after all.
          expr = translate_expr(node)
          ser!("Couldn't parse expr") if expr.nil?
          body << ExpressionStatement.new(expr)
        else
          ser!("Unknown form in Program", node.token)
        end
      end

      program
    end

    protected

    def translate_defn(list)
      decl = nil

      success = matches?(list, ":id :str? [:id*] :expr*") do |name, doc, args, body|
        decl = FunctionDeclaration.new(make_ident(name.value))
        args.inner.each do |arg|
          decl.params << make_ident(arg.value)
        end

        decl.body = block = BlockStatement.new
        inner_count = body.length
        body.each_with_index do |expr, i|
          last = (inner_count - 1 == i)

          node = translate_expr(expr)
          node = if last
            make_rstat(node)
          else
            make_estat(node)
          end

          block.body << node
        end
      end

      ser!("Expected valid defn", list[0].token) unless success
      decl
    end

    def translate_expr(expr)
      case
      when expr.identifier?
        return make_ident(expr.value)
      when expr.literal?
        return make_literal(expr.value)
      when expr.list?
        list = expr.inner
        first = list.first
        case
        when first.instance_of?(Shin::AST::MethodCall)
          property = translate_expr(list[0].id)
          object = translate_expr(list[1])
          mexp = MemberExpression.new(object, property, false)
          call = CallExpression.new(mexp)
          list[2..-1].each do |arg|
            call.arguments << translate_expr(arg)
          end
          return call
        when first.identifier?
          # function call
          call = CallExpression.new(make_ident(first.value))
          list[1..-1].each do |arg|
            call.arguments << translate_expr(arg)
          end
          return call
        else
          ser!("Unknown list expr form", expr.token)
        end
      when expr.instance_of?(Shin::AST::String)
        Literal.new(expr.value)
      else
        ser!("Unknown expr form", expr.token)
        nil
      end
    end

    def make_literal(id)
      Literal.new(id)
    end

    def make_ident(id)
      escaped_id = id.
        gsub('-', '$_').
        gsub('?', '$q').
        gsub('!', '$e').
        gsub('*', '$m').
        gsub('/', '$d').
        gsub('+', '$p').
        gsub('=', '$l').
        gsub('>', '$g').
        gsub('<', '$s').
        to_s
      Identifier.new(escaped_id)
    end

    def make_rstat(node)
      ReturnStatement.new(node)
    end

    def make_estat(node)
      ExpressionStatement.new(node)
    end

    def file
      @options[:file] || "<stdin>"
    end


    def ser!(msg, token)
      start = token.start
      length = token.length

      line, column = line_column(@input, start)
      snippet = snippet(@input, start, length)

      raise "#{msg} at #{file}:#{line}:#{column}\n\n#{snippet}\n\n"
    end
  end
end
