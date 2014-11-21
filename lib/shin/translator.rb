
require 'shin/jst'
require 'shin/ast'
require 'shin/utils'

module Shin
  # Converts Shin AST to JST
  class Translator
    include Shin::Utils::LineColumn
    include Shin::Utils::Snippet
    include Shin::Utils::Matcher
    include Shin::Utils::Mangler
    include Shin::JST

    def initialize(compiler, mod)
      @compiler = compiler
      @mod = mod
      @input = mod.source.dup
      @options = {:file => mod.file}

      @quoting = false
    end

    def translate
      ast = @mod.ast2

      requires = [Shin::Require.new('exports')]

      @mod.requires.each do |req|
        requires << req
      end

      program = Program.new
      load_shim = FunctionExpression.new
      load_shim.params << make_ident('root');
      load_shim.params << make_ident('factory')
      load_shim.body = BlockStatement.new
      define_call = CallExpression.new(make_ident('define'))
      require_arr = ArrayExpression.new
      requires.each do |req|
        require_arr.elements << make_literal(req.ns)
      end
      define_call.arguments << require_arr

      bound_factory = CallExpression.new(
        MemberExpression.new(make_ident('factory'), make_ident('bind'), false),
        [make_ident('this')])
      define_call.arguments << bound_factory
      load_shim.body.body << ExpressionStatement.new(define_call)

      factory = FunctionExpression.new
      requires.each do |req|
        factory.params << make_ident(req.as)
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
      init_call.arguments << make_literal(@mod.ns)
      body << ExpressionStatement.new(init_call)

      @mod.requires.each do |req|
        if req.all?
          unless req.js?
            dep = @compiler.modules[req.ns]
            raise "Couldn't find req #{req.ns}" unless dep
            defs = dep.defs
            dep_id = make_ident(req.as)

            decl = VariableDeclaration.new
            body << decl
            defs.each_key do |d|
              id = make_ident(d)
              mexpr = MemberExpression.new(dep_id, id, false)
              decl.declarations << VariableDeclarator.new(id, mexpr)
            end
          end
        elsif !req.refer.empty?
          dep_id = make_ident(req.as)
          decl = VariableDeclaration.new
          body << decl

          req.refer.each do |d|
            id = make_ident(d)
            mexpr = MemberExpression.new(dep_id, id, false)
            decl.declarations << VariableDeclarator.new(id, mexpr)
          end
        end
      end

      ast.each do |node|
        case
        when matches?(node, "(defn :expr*)")
          body << translate_defn(node.inner.drop 1)
        when matches?(node, "(defmacro :expr*)")
          unless @mod.is_macro
            ser!("Macro in a non-macro module", node)
          end
          body << translate_defn(node.inner.drop 1)
        when matches?(node, "(def :expr*)")
          body << translate_def(node.inner.drop 1)
        when matches?(node, ":expr")
          # any expression is a statement, after all.
          expr = translate_expr(node) or ser!("Couldn't parse expr", node)
          body << ExpressionStatement.new(expr)
        else
          ser!("Unknown form in Program", node)
        end
      end

      @mod.jst = program
    end

    protected

    def translate_export(list)
      matches?(list, ":sym :sym?") do |name, aka|
        aka ||= name
        mexp = MemberExpression.new(make_ident('exports'), make_ident(aka.value), false)
        return AssignmentExpression.new(mexp, make_ident(name.value))
      end or ser!("Invalid export form")
    end

    def translate_let(list)
      matches?(list, "[] :expr*") do |bindings, exprs|
        anon = FunctionExpression.new
        anon.body = BlockStatement.new
        call = CallExpression.new(anon)

        ser!("Invalid let form: odd number of binding forms", list) unless bindings.inner.length.even?
        bindings.inner.each_slice(2) do |binding|
          name, val = binding

          case name
          when Shin::AST::Sequence
            ser!("Destructuring isn't supported yet.", name)
          when Shin::AST::Symbol
            # all good
          else
            ser!("Invalid let form: first binding form should be a symbol or collection", name)
          end

          decl = VariableDeclaration.new
          decl.declarations << VariableDeclarator.new(make_ident(name.value), translate_expr(val))
          anon.body.body << decl;
        end

        translate_body_into_block(exprs, anon.body)
        return call
      end or ser!("Invalid let form", list)
    end

    def translate_def(list)
      matches?(list, ":sym :expr*") do |name, rest|
        decl = VariableDeclaration.new
        dtor = VariableDeclarator.new(make_ident(name.value))

        case
        when matches?(rest, ":str :expr")
          doc, expr = rest
          dtor.init = translate_expr(expr)
        when matches?(rest, ":expr")
          expr = rest.first
          dtor.init = translate_expr(expr)
        else
          ser!("Invalid def form", list)
        end

        ex = make_ident("exports/#{name}")
        dtor.init = AssignmentExpression.new(ex, dtor.init)
        decl.declarations << dtor
        return decl
      end or ser!("Invalid def form", list)
    end

    def translate_defn(list)
      matches?(list, ":sym :str? [:sym*] :expr*") do |name, doc, args, body|
        f = FunctionExpression.new(make_ident(name.value))
        args.inner.each do |arg|
          f.params << make_ident(arg.value)
        end

        f.body = block = BlockStatement.new
        translate_body_into_block(body, block)

        decl = VariableDeclaration.new
        dtor = VariableDeclarator.new(make_ident(name.value))
        ex = make_ident("exports/#{name}")
        dtor.init = AssignmentExpression.new(ex, f)
        decl.declarations << dtor

        return decl
      end or ser!("Invalid defn form", list)
    end

    def translate_fn(list)
      matches?(list, "[:sym*] :expr*") do |args, body|
        expr = FunctionExpression.new
        args.inner.each do |arg|
          expr.params << make_ident(arg.value)
        end

        expr.body = BlockStatement.new
        translate_body_into_block(list.drop(1), expr.body)
        return expr
      end or ser!("Invalid fn form", list)
    end

    def translate_body_into_block(body, block)
      inner_count = body.length
      body.each_with_index do |expr, i|
        node = translate_expr(expr)
        last = (inner_count - 1 == i)
        block.body << (last ? ReturnStatement : ExpressionStatement).new(node)
      end
    end

    def translate_expr(expr)
      case expr
      when Shin::AST::Symbol
        if @quoting
          return CallExpression.new(make_ident("symbol"), [make_literal(expr.value)])
        end

        return make_ident(expr.value)
      when Shin::AST::RegExp
        return NewExpression.new(make_ident("RegExp"), [make_literal(expr.value)])
      when Shin::AST::Literal
        return make_literal(expr.value)
      when Shin::AST::Deref
        t = expr.token
        return translate_expr(Shin::AST::List.new(t, [Shin::AST::Symbol.new(t, "deref"), expr.inner]))
      when Shin::AST::Quote, Shin::AST::SyntaxQuote
        # TODO: find a less terrible solution.
        @quoting = true
        expr = translate_expr(expr.inner)
        @quoting = false
        return expr
      when Shin::AST::Vector
        first = expr.inner.first
        if first && first.sym?('$')
          els = expr.inner.drop(1).map { |el| translate_expr(el) }
          return ArrayExpression.new(els)
        else
          els = expr.inner.map { |el| translate_expr(el) }
          return CallExpression.new(make_ident("vector"), els)
        end
      when Shin::AST::Set
        arr = ArrayExpression.new(expr.inner.map { |el| translate_expr(el) })
        return CallExpression.new(make_ident("set"), [arr])
      when Shin::AST::Map
        first = expr.inner.first
        if first && first.sym?('$')
          list = expr.inner.drop(1)
          props = []
          list.each_slice(2) do |pair|
            key, val = pair
            props << Property.new(translate_expr(key), translate_expr(val))
          end
          return ObjectExpression.new(props)
        else
          ser!("Map literal requires even number of forms", expr) unless expr.inner.count.even?
          els = expr.inner.map { |el| translate_expr(el) }
          return CallExpression.new(make_ident("hash-map"), els)
        end
      when Shin::AST::Keyword
        return CallExpression.new(make_ident("keyword"), [make_literal(expr.value)])
      when Shin::AST::List
        if @quoting
          els = expr.inner.map { |el| translate_expr(el) }
          return CallExpression.new(make_ident("list"), els)
        end

        list = expr.inner
        first = list.first
        unless first
          return CallExpression.new(make_ident("list"))
        end

        case
        when Shin::AST::MethodCall === first
          property = make_ident(list[0].sym.value)
          object = translate_expr(list[1])
          mexp = MemberExpression.new(object, property, false)
          call = CallExpression.new(mexp)
          list.drop(2).each do |arg|
            call.arguments << translate_expr(arg)
          end
          return call
        when Shin::AST::FieldAccess === first
          property = make_ident(list[0].sym.value)
          object = translate_expr(list[1])
          return MemberExpression.new(object, property, false)
        when first.sym?("export")
          return translate_export(list.drop(1))
        when first.sym?("let")
          return translate_let(list.drop(1))
        when first.sym?("fn")
          return translate_fn(list.drop(1))
        when first.sym?("do")
          anon = FunctionExpression.new
          anon.body = BlockStatement.new
          translate_body_into_block(list.drop(1), anon.body)
          return CallExpression.new(anon)
        when first.sym?("if")
          anon = FunctionExpression.new
          anon.body = BlockStatement.new
          body = anon.body.body

          test, consequent, alternate = list.drop 1
          fi = IfStatement.new(translate_expr(test))
          fi.consequent  = BlockStatement.new
          translate_body_into_block([consequent], fi.consequent) if consequent
          fi.alternate = BlockStatement.new
          translate_body_into_block([alternate], fi.alternate) if alternate
          body << fi

          return CallExpression.new(anon)
        else
          # function call
          call = CallExpression.new(translate_expr(first))
          list.drop(1).each do |arg|
            call.arguments << translate_expr(arg)
          end
          return call
        end
      when Shin::AST::Unquote
        call_expr = CallExpression.new(make_ident('--unquote'))
        ser!("Invalid usage of unquoting outside of a quote", expr) unless @quoting

        spliced = false
        inner = expr.inner
        if Shin::AST::Deref === inner
          spliced = true
          inner = inner.inner
        end

        @quoting = false
        call_expr.arguments << translate_expr(inner)
        @quoting = true

        call_expr.arguments << Literal.new(spliced)
        return call_expr
      else
        ser!("Unknown expr form #{expr}", expr.token)
        nil
      end
    end

    def make_literal(id)
      Literal.new(id)
    end

    def make_ident(id)
      matches = /^([^\/]+)\/(.*)?$/.match(id)
      if matches
        ns, name = matches.to_a.drop(1)
        MemberExpression.new(make_ident(ns), make_ident(name), false)
      else
        Identifier.new(mangle(id))
      end
    end

    def file
      @options[:file] || "<stdin>"
    end

    def ser!(msg, token)
      token = token.to_a.first if token.respond_to?(:to_a)
      token = token.token if Shin::AST::Node === token
      token = nil unless Shin::AST::Token === token

      start  = token ? token.start  : 0
      length = token ? token.length : 1

      line, column = line_column(@input, start)
      snippet = snippet(@input, start, length)

      raise "#{msg} at #{file}:#{line}:#{column}\n\n#{snippet}\n\n"
    end
  end
end
