
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
      @seed = 4141
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
        next if req.macro? && !@mod.macro?
        require_arr.elements << make_literal(req.slug)
      end
      define_call.arguments << require_arr

      bound_factory = CallExpression.new(
        MemberExpression.new(make_ident('factory'), make_ident('bind'), false),
        [make_ident('this')])
      define_call.arguments << bound_factory
      load_shim.body.body << ExpressionStatement.new(define_call)

      factory = FunctionExpression.new
      requires.each do |req|
        next if req.macro? && !@mod.macro?
        factory.params << make_ident(req.as_sym)
      end
      factory.body = BlockStatement.new

      shim_call = CallExpression.new(load_shim)
      shim_call.arguments << ThisExpression.new
      shim_call.arguments << factory
      program.body << ExpressionStatement.new(shim_call)

      body = factory.body.body

      unless @mod.macro?
        shin_init = MemberExpression.new(make_ident('shin'), make_ident('init'), false)
        init_call = CallExpression.new(shin_init)
        init_call.arguments << make_ident('this')
        init_call.arguments << make_literal(@mod.ns)
        body << ExpressionStatement.new(init_call)
      end

      @mod.requires.each do |req|
        next if req.macro? && !@mod.macro?
        if req.all?
          unless req.js?
            dep = @compiler.modules[req]
            raise Shin::Error, "Couldn't find req #{req.slug}" unless dep
            defs = dep.defs
            dep_id = make_ident(req.as_sym)

            decl = VariableDeclaration.new
            defs.each_key do |d|
              id = make_ident(d)
              mexpr = MemberExpression.new(dep_id, id, false)
              decl.declarations << VariableDeclarator.new(id, mexpr)
            end

            body << decl unless decl.declarations.empty?
          end
        elsif !req.refer.empty?
          dep_id = make_ident(req.as)
          decl = VariableDeclaration.new

          req.refer.each do |d|
            id = make_ident(d)
            mexpr = MemberExpression.new(dep_id, id, false)
            decl.declarations << VariableDeclarator.new(id, mexpr)
          end

          body << decl unless decl.declarations.empty?
        end
      end

      ast.each do |node|
        case node
        when Shin::AST::List
          first = node.inner.first
          if first
            case
            when first.sym?("def")
              body << translate_def(node.inner.drop 1)
            when first.sym?("defn")
              body << translate_defn(node.inner.drop 1)
            when first.sym?("defmacro")
              ser!("Macro in a non-macro module", node) unless @mod.macro?
              body << translate_defn(node.inner.drop 1)
            when first.sym?("defprotocol")
              ser!("defprotocol: stub", first)
            when first.sym?("deftype")
              ser!("deftype: stub", first)
            else
              expr = translate_expr(node) or ser!("Couldn't parse expr", node)
              body << ExpressionStatement.new(expr)
            end
          else
            expr = translate_expr(node) or ser!("Couldn't parse expr", node)
            body << ExpressionStatement.new(expr)
          end
        else
        end
      end

      @mod.jst = program
    end

    protected

    EXPORT_PATTERN = ":sym :sym?".freeze

    def translate_export(list)
      matches?(list, EXPORT_PATTERN) do |name, aka|
        aka ||= name
        mexp = MemberExpression.new(make_ident('exports'), make_ident(aka.value), false)
        return AssignmentExpression.new(mexp, make_ident(name.value))
      end or ser!("Invalid export form")
    end

    def destructuring_needed?(lhs)
      !lhs.sym? || lhs.sym?('&')
    end

    # 'VDFE' = Variable-Decl from Expr - just an old acronym
    # from the ooc days...
    def vdfe(block, name, expr)
      expr = translate_expr(expr) if Shin::AST::Node === expr

      decl = VariableDeclaration.new
      dtor = VariableDeclarator.new(make_ident(name), expr)
      decl.declarations << dtor
      block.body << decl
    end

    def destructure(block, lhs, rhs)
      case lhs
      when Shin::AST::Vector
        destructure_vector(block, lhs.inner, rhs)
      when Shin::AST::Map
        destructure_map(block, lhs.inner, rhs)
      when Shin::AST::Symbol
        vdfe(block, lhs.value, rhs)
      else
        ser!("Invalid let form: first binding form should be a symbol or collection, instead, got #{lhs.class}", lhs)
      end
    end

    def destructure_vector(block, inner, rhs)
      done = false
      list = inner
      rhs_memo = fresh("rhsmemo")
      vdfe(block, rhs_memo, rhs)
      rhs_sym = Shin::AST::Symbol.new(rhs.token, rhs_memo)
      rhs_id = make_ident(rhs_memo)

      i = 0
      until list.empty?
        name = list.first

        if name.kw?
          directive = name.value
          case directive
          when 'as'
            list = list.drop(1)
            as_sym = list.first
            ser!("Expected symbol in :as directive, got #{as_sym.class}") unless as_sym.sym?
            vdfe(block, as_sym.value, rhs_sym)
          else
            ser!("Unknown directive in vector destructuring: :#{directive}", name)
          end
        else
          ser!("Unexpected argument", name) if done
          if name.sym?('&')
            done = true
            list = list.drop(1)
            if rest = list.first
              part = CallExpression.new(make_ident('nthnext'), [rhs_id, make_literal(i)])
              vdfe(block, rest.value, part)
            end
          else
            part = CallExpression.new(make_ident('nth'), [rhs_id, make_literal(i)])
            if name.sym?
              vdfe(block, name.value, part) 
            else
              part_memo = fresh("partmemo")
              vdfe(block, part_memo, part)
              destructure(block, name, Shin::AST::Symbol.new(name.token, part_memo))
            end
          end
        end

        list = list.drop(1)
        i += 1
      end
    end

    def destructure_map(block, inner, rhs, alt_map = {})
      rhs_memo = fresh("rhsmemo")
      vdfe(block, rhs_memo, rhs)
      rhs_sym = Shin::AST::Symbol.new(rhs.token, rhs_memo)
      rhs_id = make_ident(rhs_memo)

      # filter out 'or', store in alt_map
      pairs = []
      inner.each_slice(2) do |pair|
        k, v = pair
        if k.kw?('or')
          ser!("Expected map after :or", v) unless v.map?
          v.inner.each_slice(2) do |alt|
            kk, vv = alt
            alt_map[kk.value] = vv
          end
        else
          pairs << pair
        end
      end

      shortcut_directives = %w(keys strs syms)
      pairs.each do |pair|
        name, map_key = pair

        if name.kw?
          if shortcut_directives.include?(name.value)
            directive = name.value
            ser!("Expected vector after :#{directive} in map destructuring, got #{map_key.class}", map_key) unless map_key.vector?

            binds = []
            map_key.inner.each do |sym|
              ser!("Expected symbol in :#{directive} vector (in map destructuring)") unless sym.sym?
              binds << sym
              binds << case directive
              when 'keys' then Shin::AST::Keyword.new(sym.token, sym.value)
              when 'strs' then Shin::AST::String.new(sym.token, sym.value)
              when 'syms'
                s = Shin::AST::Symbol.new(sym.token, sym.value)
                Shin::AST::Quote.new(sym.token, s)
              else raise Shin::SyntaxError, "Unknown directive #{directive}"
              end
            end
            destructure_map(block, binds, rhs, alt_map)
          elsif 'as' === name.value
            vdfe(block, map_key.value, rhs_sym)
          else
            ser!("Unknown directive in map destructuring - :#{name.value}", name)
          end
        else
          part = CallExpression.new(make_ident('get'), [rhs_id, translate_expr(map_key)])
          if name.sym?
            if alt = alt_map[name.value]
              part.arguments << translate_expr(alt)
            end
            vdfe(block, name.value, part)
          else
            part_memo = fresh("partmemo")
            vdfe(block, part_memo, part)
            destructure(block, name, Shin::AST::Symbol.new(name.token, part_memo))
          end
        end
      end
    end

    LET_PATTERN = "[] :expr*".freeze

    def translate_let(list)
      matches?(list, LET_PATTERN) do |bindings, exprs|
        anon = FunctionExpression.new
        block = anon.body = BlockStatement.new
        call = CallExpression.new(anon)

        ser!("Invalid let form: odd number of binding forms", list) unless bindings.inner.length.even?
        bindings.inner.each_slice(2) do |binding|
          lhs, rhs = binding
          if destructuring_needed?(lhs)
            destructure(block, lhs, rhs)
          else
            vdfe(block, lhs.value, rhs)
          end
        end

        translate_body_into_block(exprs, block)
        return call
      end or ser!("Invalid let form", list)
    end

    DEF_PATTERN             = ":sym :expr*".freeze
    DEF_WITH_DOC_PATTERN    = ":str :expr".freeze
    DEF_WITHOUT_DOC_PATTERN = ":expr".freeze

    def translate_def(list)
      matches?(list, DEF_PATTERN) do |name, rest|
        decl = VariableDeclaration.new
        dtor = VariableDeclarator.new(make_ident(name.value))

        case
        when matches?(rest, DEF_WITH_DOC_PATTERN)
          doc, expr = rest
          dtor.init = translate_expr(expr)
        when matches?(rest, DEF_WITHOUT_DOC_PATTERN)
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

    DEFN_PATTERN = ":sym :str? [:expr*] :expr*".freeze

    def translate_defn(list)
      matches?(list, DEFN_PATTERN) do |name, doc, args, body|
        f = translate_fn_inner(args, body, :name => name.value)

        decl = VariableDeclaration.new
        dtor = VariableDeclarator.new(make_ident(name.value))
        ex = make_ident("exports/#{name}")
        dtor.init = AssignmentExpression.new(ex, f)
        decl.declarations << dtor

        return decl
      end or ser!("Invalid defn form", list)
    end

    def translate_closure(closure)
      t = closure.token
      arg_map = {}
      body = desugar_closure_inner(closure.inner, arg_map)

      num_args = arg_map.keys.max || 0
      args = (0..num_args).map do |index|
        name = arg_map[index] || fresh("aarg#{index}-")
        Shin::AST::Symbol.new(t, name)
      end
      translate_fn_inner(Shin::AST::Vector.new(t, args), [body])
    end

    def desugar_closure_inner(node, arg_map)
      case node
      when Sequence
        node = node.clone
        node.inner.map! { |x| desugar_closure_inner(x, arg_map) }
        node
      when Symbol
        if node.value.start_with?('%')
          index = closure_arg_to_index(node)
          name = arg_map[index]
          unless name
            name = arg_map[index] = fresh("aarg#{index}-")
          end
          return Shin::AST::Symbol.new(node.token, name)
        end
        node
      when Closure
        ser!("Nested closures are forbidden", node)
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
        ser!("Invalid closure argument: #{name}", sym) unless num =~ /^[0-9]+$/
        num.to_i - 1
      end
    end

    FN_PATTERN = "[:expr*] :expr*".freeze

    def translate_fn(list)
      matches?(list, FN_PATTERN) do |args, body|
        return translate_fn_inner(args, body)
      end or ser!("Invalid fn form", list)
    end

    def translate_fn_inner(args, body, name: nil)
      expr = FunctionExpression.new(name ? make_ident(name) : nil)
      expr.body = BlockStatement.new

      if args.inner.any? { |x| destructuring_needed?(x) }
        t = args.token
        lhs = Shin::AST::Vector.new(t, args.inner)
        apply     = Shin::AST::MethodCall.new(t, Shin::AST::Symbol.new(t, 'apply'))
        vector    = Shin::AST::Symbol.new(t, 'vector')
        _nil      = Shin::AST::Nil.new(t)
        arguments = Shin::AST::Symbol.new(t, 'arguments')
        rhs = Shin::AST::List.new(t, [apply, vector, _nil, arguments])
        destructure(expr.body, lhs, rhs)
      else
        args.inner.each do |arg|
          expr.params << make_ident(arg.value)
        end
      end

      translate_body_into_block(body, expr.body)
      return expr
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
          # function call or instanciation
          call = if first.sym? && first.value.end_with?('.')
                   type_name = first.value[0..-2]
                   NewExpression.new(make_ident(type_name))
                 else
                   CallExpression.new(translate_expr(first))
                 end

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
      when Shin::AST::Closure
        translate_closure(expr)
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

      raise Shin::SyntaxError, "#{msg} at #{file}:#{line}:#{column}\n\n#{snippet}\n\n"
    end

    def fresh(prefix)
      "$$__#{prefix}#{@seed += 1}"
    end
  end
end
