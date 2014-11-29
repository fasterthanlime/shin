
require 'shin/jst'
require 'shin/ast'
require 'shin/utils'
require 'shin/jst_builder'

module Shin
  # Converts Shin AST to JST
  class Translator
    DEBUG = ENV['TRANSLATOR_DEBUG']

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
      @builder = JstBuilder.new

      @quoting = false
      @seed = 0
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
      load_shim.body << ExpressionStatement.new(define_call)

      factory = FunctionExpression.new
      requires.each do |req|
        next if req.macro? && !@mod.macro?
        factory.params << make_ident(req.as_sym)
      end

      shim_call = CallExpression.new(load_shim)
      shim_call.arguments << ThisExpression.new
      shim_call.arguments << factory
      program.body << ExpressionStatement.new(shim_call)

      body = factory.body

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

      @builder.into(body, :statement) do
        ast.each do |node|
          case node
          when Shin::AST::List
            first = node.inner.first
            if first && first.sym?
              rest = node.inner.drop(1)
              case first.value
              when "def"
                translate_def(rest)
              when "defn"
                translate_defn(rest)
              when "defn-"
                translate_defn(rest, :export => false)
              when "defmacro"
                ser!("Macro in a non-macro module", node) unless @mod.macro?
                translate_defn(rest)
              when "defprotocol"
                translate_defprotocol(rest)
              when "deftype"
                translate_deftype(rest)
              else
                tr(node)
              end
            else
              tr(node)
            end
          else
          end
        end
      end

      @mod.jst = program
    end

    protected

    EXPORT_PATTERN = ":sym :sym?".freeze

    def destructuring_needed?(lhs)
      !lhs.sym? || lhs.sym?('&')
    end

    def as_expr(expr)
      arr = []
      @builder.into(arr, :expression) do
        tr(expr)
      end
      arr[0]
    end

    def as_specified(expr, mode)
      arr = []
      @builder.into(arr, mode) do
        tr(expr)
      end
      arr[0]
    end

    def as_parent(expr)
      as_specified(expr, @builder.mode)
    end

    def destructure(lhs, rhs, mode: :declare)
      case lhs
      when Shin::AST::Vector
        destructure_vector(lhs.inner, rhs, mode)
      when Shin::AST::Map
        destructure_map(lhs.inner, rhs, mode)
      when Shin::AST::Symbol
        decline(lhs, rhs, mode)
      else
        ser!("Invalid let form: first binding form should be a symbol or collection, instead, got #{lhs.class}", lhs)
      end
    end

    def destructure_vector(inner, rhs, mode)
      done = false
      list = inner
      rhs_memo = fresh("rhsmemo")
      @builder << make_decl(rhs_memo, rhs)
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
            decline(as_sym, rhs_sym, mode)
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
              @builder << make_decl(rest.value, part)
            end
          else
            part = CallExpression.new(make_ident('nth'), [rhs_id, make_literal(i)])
            if name.sym?
              @builder << make_decl(name.value, part)
            else
              part_memo = fresh("partmemo")
              @builder << make_decl(part_memo, part)
              destructure(name, Shin::AST::Symbol.new(name.token, part_memo))
            end
          end
        end

        list = list.drop(1)
        i += 1
      end
    end

    def destructure_map(inner, rhs, mode, alt_map = {})
      rhs_memo = fresh("rhsmemo")
      @builder << make_decl(rhs_memo, rhs)
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
            destructure_map(binds, rhs, mode, alt_map)
          elsif 'as' === name.value
            decline(map_key, rhs_sym, mode)
          else
            ser!("Unknown directive in map destructuring - :#{name.value}", name)
          end
        else
          part = CallExpression.new(make_ident('get'), [rhs_id, as_expr(map_key)])
          if name.sym?
            if alt = alt_map[name.value]
              part.arguments << as_expr(alt)
            end
            decline(name, part, mode)
          else
            part_memo = fresh("partmemo")
            @builder << make_decl(part_memo, part)
            destructure(name, Shin::AST::Symbol.new(name.token, part_memo))
          end
        end
      end
    end

    LET_PATTERN = "[] :expr*".freeze

    LOGIC_MAP = {
      "or"  => "||",
      "and" => "&&",
    }

    def translate_logic(op, rest)
      real = LOGIC_MAP[op.value]
      ser!("Unknown operator #{op.value}") unless real

      case rest.length
      when 0
        ser!("Invalid use of #{op.value}, needs at least one operand", op)
      when 1
        tr(rest.first)
        return
      end

      truthy = Symbol.new(op.token, "truthy")
      truthy_rest = rest.map do |x|
        List.new(x.token, Hamster.vector(truthy, x))
      end
      translate_comp(Symbol.new(op.token, real), truthy_rest)
    end

    def translate_comp(op, rest)
      terms = []

      list = rest.map { |x| as_expr(x) }

      while list.size >= 2
        l, r = list
        list = list.drop(1)
        terms << BinaryExpression.new(op.value, l, r)
      end
      ser!("Invalid use of #{op.value}, needs at least two operands", op) if terms.empty?

      if terms.length == 1
        @builder << terms.first
      else
        res = terms.first
        terms = terms.drop(1)
        until terms.empty?
          term = terms.first
          res = BinaryExpression.new('&&', res, term)
          terms = terms.drop(1)
        end
        @builder << res
      end
      nil
    end

    def translate_let(list)
      matches?(list, LET_PATTERN) do |bindings, body|
        unless bindings.inner.length.even?
          ser!("Invalid let form: odd number of binding forms", list)
        end

        scope = Scope.new
        vase = case @builder.mode
               when :expression
                 fn = FunctionExpression.new
                 @builder << CallExpression.new(fn)
                 fn
               when :statement, :return
                 block = BlockStatement.new
                 @builder << block
                 block
               else
                 raise "let in unknown builder mode: #{@builder.mode}"
               end

        @builder.with_scope(scope) do
          @builder.into(vase, :statement) do
            bindings.inner.each_slice(2) do |binding|
              lhs, rhs = binding
              destructure(lhs, rhs)
            end
          end

          case @builder.mode
          when :expression
            # return, we made a return-friendly vase (anon fn)
            trbody(body, vase)
          when :statement
            # only statements, don't care about return value
            @builder.into(vase, :statement) do
              treach(body)
            end
          when :return
            # return at the end, we're in a return-friendly vase
            trbody(body, vase)
          else
            raise "let in unknown builder mode: #{@builder.mode}"
          end
        end

      end or ser!("Invalid let form", list)
      nil
    end

    def translate_do(list)
      case @builder.mode
      when :expression
        anon = FunctionExpression.new
        trbody(list, anon.body)
        @builder << CallExpression.new(anon)
      when :statement
        @builder.into!(BlockStatement.new, :statement) do
          treach(list)
        end
      when :return
        block = BlockStatement.new
        trbody(list, block)
        @builder << block
      else
        raise "do in unknown builder mode: #{@builder.mode}"
      end
      nil
    end

    def translate_if(list)
      test, consequent, alternate = list

      case @builder.mode
      when :expression
        cond = ConditionalExpression.new(as_expr(test))
        cond.consequent = consequent ? as_expr(consequent) : make_literal(nil)
        cond.alternate  = alternate  ? as_expr(alternate)  : make_literal(nil)
        @builder << cond
      when :statement, :return
        ifs = IfStatement.new(as_expr(test))
        @builder.into(ifs.consequent = BlockStatement.new, @builder.mode) { tr(consequent) } if consequent
        @builder.into(ifs.alternate  = BlockStatement.new, @builder.mode) { tr(alternate ) } if alternate 
        @builder << ifs
      else
        raise "if in unknown builder mode: #{@builder.mode}"
      end
      nil
    end

    def translate_cond(list)
      tr(unwrap_cond(list))
    end

    def unwrap_cond(list)
      if list.size >= 2
        cond = list.first; list = list.drop(1)
        form = list.first; list = list.drop(1)

        t = cond.token
        fi = Shin::AST::Symbol.new(t, "if")
        inner = Hamster.vector(fi, cond, form, unwrap_cond(list))
        Shin::AST::List.new(t, inner)
      else
        nil
      end
    end

    def translate_condp(list)
      # TODO: support :>>
      form = list.first; list = list.drop(1)
      rhs  = list.first; list = list.drop(1)
      
      i = 0
      while i < list.size
        lhs = list[i]
        unless lhs.kw?('else')
          inner = Hamster.vector(form, lhs, rhs)
          list = list.set(i, List.new(lhs.token, inner))
        end
        i += 2
      end

      tr(unwrap_cond(list))
    end

    LOOP_PATTERN            = "[:expr*] :expr*"

    def translate_loop(list)
      matches?(list, LOOP_PATTERN) do |bindings, body|
        translate_loop_inner(bindings.inner, body)
      end or ser!("Invalid loop form", list)
      nil
    end

    def translate_loop_inner(bindings, body)
      t = body.first.token
      scope = Scope.new

      mode = @builder.mode
      support = case @builder.mode
                when :expression
                  FunctionExpression.new
                when :statement, :return
                  BlockStatement.new
                else
                  raise "loop in unknown builder mode: #{@builder.mode}"
                end

      @builder.with_scope(scope) do
        @builder.into(support, :statement) do
          lhs_bindings = Hamster.vector

          bindings.each_slice(2) do |binding|
            lhs, rhs = binding
            lhs_bindings <<= lhs
            destructure(lhs, rhs)
          end

          recur_id = Identifier.new(fresh('recur_sentinel'))
          @builder << make_decl(recur_id, make_literal(true))

          loup = WhileStatement.new(recur_id)
          support << loup
          reset = AssignmentExpression.new(recur_id, make_literal(false))
          loup << ExpressionStatement.new(reset)

          anchor = Anchor.new(lhs_bindings, recur_id)
          @builder.with_anchor(anchor) do
            case mode
            when :expression
              trbody(body, loup.body)
            when :statement
              @builder.into(loup.body, :statement) do
                treach(body)
              end
            when :return
              trbody(body, loup.body)
            else
              raise "loop in unsupported builder mode: #{mode}"
            end
          end
        end
      end

      case @builder.mode
      when :expression
        @builder << CallExpression.new(support)
      when :statement, :return
        @builder << support
      else
        raise "loop in unknown builder mode: #{@builder.mode}"
      end
    end

    DEFPROTOCOL_PATTERN     = ":sym :str? :list*".freeze

    def translate_defprotocol(list)
      matches?(list, DEFPROTOCOL_PATTERN) do |name, doc, sigs|
        empty = ObjectExpression.new
        ex = make_ident("exports/#{name}")
        ass = AssignmentExpression.new(ex, empty)
        @builder << make_decl(Identifier.new(name.value), ass)

        sigs.each do |sig|
          name = sig.inner.first
          name_ident = make_ident(name.value)
          decl = VariableDeclaration.new
          dtor = VariableDeclarator.new(name_ident)

          dtor.init = fn = FunctionExpression.new(fn)
          arguments = make_ident('arguments')
          this_access = MemberExpression.new(arguments, make_literal(0), true)

          meth_acc = MemberExpression.new(this_access, name_ident, false)
          apply_acc = MemberExpression.new(meth_acc, make_ident('apply'), false)
          first_arg = MemberExpression.new(arguments, make_literal(0), true)
          meth_call = CallExpression.new(apply_acc)
          meth_call.arguments << first_arg
          meth_call.arguments << make_ident('arguments')
          fn.body << ReturnStatement.new(meth_call)

          ex = make_ident("exports/#{name}")
          dtor.init = AssignmentExpression.new(ex, dtor.init)
          decl.declarations << dtor

          @builder << decl
        end
      end or ser!("Invalid defprotocol form", list)
    end

    DEFTYPE_PATTERN         = ":sym :str? :vec? :expr*".freeze

    def translate_deftype(list)
      matches?(list, DEFTYPE_PATTERN) do |name, doc, fields, body|
        decl = VariableDeclaration.new
        dtor = VariableDeclarator.new(make_ident(name.value))

        wrapper = FunctionExpression.new
        block = wrapper.body
        dtor.init = CallExpression.new(wrapper)

        # TODO: members / params
        ctor = FunctionExpression.new

        fields.inner.each do |field|
          next if field.meta?  # FIXME: woooooooooo #28

          fname = field.value
          ctor.params << make_ident(fname)
          slot = make_ident("this/#{fname}")
          ass = AssignmentExpression.new(slot, make_ident(fname))
          ctor.body << ExpressionStatement.new(ass)
        end if fields

        @builder << make_decl(name.value, ctor)

        prototype_mexpr = MemberExpression.new(make_ident(name.value), make_ident("prototype"), false)
        protocols_mexpr = MemberExpression.new(prototype_mexpr, make_ident("_protocols"), false)
        empty_arr = ArrayExpression.new
        block.body << ExpressionStatement.new(AssignmentExpression.new(protocols_mexpr, empty_arr))

        body.each do |limb|
          case
          when limb.list?
            id = limb.inner.first
            fn = nil

            type_scope = Scope.new

            @builder.with_scope(type_scope) do
              self_name = fresh("self")
              fields.inner.each do |field|
                next if field.meta?  # FIXME: woooooooooo #28
                type_scope[field.value] = "#{self_name}/#{field.value}"
              end if fields

              # FIXME: That's uh, not good. Feex it!
              fn = nil
              matches?(limb.inner.drop(1), FN_PATTERN) do |name, args, body|
                fn = translate_fn_inner(args, body, :name => (name ? name.value : nil))
              end or ser!("Invalid fn form", list)

              self_decl = VariableDeclaration.new
              self_dtor = VariableDeclarator.new(make_ident(self_name), make_ident("this"))
              self_decl.declarations << self_dtor
              fn.body.body.unshift(self_decl)
              @builder << fn
            end

            slot = MemberExpression.new(prototype_mexpr, make_ident(id.value), false)
            ass = AssignmentExpression.new(slot, fn)
            block.body << ExpressionStatement.new(ass)
          when limb.sym?
            # Ehhhh ignore for now.
            push = MemberExpression.new(protocols_mexpr, make_ident('push'), false)
            call = CallExpression.new(push)
            call.arguments << make_ident(limb.value)
            block.body << ExpressionStatement.new(call)
          else
            ser!("Unrecognized thing in deftype", limb)
          end
        end

        # return our new type.
        block.body << ReturnStatement.new(make_ident(name.value))

        ex = make_ident("exports/#{name}")
        dtor.init = AssignmentExpression.new(ex, dtor.init)
        decl.declarations << dtor

        @builder << decl
      end or ser!("Invalid deftype form", list)
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
          dtor.init = as_expr(expr)
        when matches?(rest, DEF_WITHOUT_DOC_PATTERN)
          expr = rest.first
          dtor.init = as_expr(expr)
        else
          ser!("Invalid def form", list)
        end

        ex = make_ident("exports/#{name}")
        dtor.init = AssignmentExpression.new(ex, dtor.init)
        decl.declarations << dtor
        @builder << decl
      end or ser!("Invalid def form", list)
    end

    DEFN_PATTERN       = ":sym :str? [:expr*] :expr*".freeze
    DEFN_MULTI_PATTERN = ":sym :str? :list+".freeze

    def translate_defn(list, export: true)
      f = nil
      _name = nil

      matches?(list, DEFN_PATTERN) do |name, doc, args, body|
        _name = name
        f = translate_fn_inner(args, body, :name => name.value)
      end or matches?(list, DEFN_MULTI_PATTERN) do |name, doc, variants|
        _name = name
        f = translate_fn_inner_multi(variants, :name => name.value)
      end or ser!("Invalid defn form", list)

      lhs = make_ident(_name.value)
      rhs = if export
              ex = make_ident("exports/#{_name}")
              AssignmentExpression.new(ex, f)
            else
              f
            end
      @builder << make_decl(lhs, rhs)
    end

    def translate_closure(closure)
      t = closure.token
      arg_map = {}
      body = desugar_closure_inner(closure.inner, arg_map)

      num_args = arg_map.keys.max || 0
      args = Hamster.vector()
      (0..num_args).map do |index|
        name = arg_map[index] || fresh("aarg#{index}-")
        args <<= Shin::AST::Symbol.new(t, name)
      end
      @builder << translate_fn_inner(Shin::AST::Vector.new(t, args), [body])
      nil
    end

    def desugar_closure_inner(node, arg_map)
      case node
      when Sequence
        inner = node.inner
        inner.each_with_index do |child, i|
          poster_child = desugar_closure_inner(child, arg_map)
          inner = inner.set(i, poster_child) if poster_child != child
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

    FN_PATTERN = ":sym? [:expr*] :expr*".freeze

    def translate_fn(list)
      matches?(list, FN_PATTERN) do |name, args, body|
        fn = translate_fn_inner(args, body, :name => (name ? name.value : nil))
        @builder << fn
      end or ser!("Invalid fn form", list)
      nil
    end

    def translate_fn_inner(args, body, name: nil)
      fn = FunctionExpression.new(name ? make_ident(name) : nil)

      scope = Scope.new
      scope[name] = name if name

      @builder.with_scope(scope) do
        if args.inner.any? { |x| destructuring_needed?(x) }
          t = args.token
          lhs = Shin::AST::Vector.new(t, args.inner)
          apply     = Shin::AST::Symbol.new(t, '.apply')
          vector    = Shin::AST::Symbol.new(t, 'vector')
          _nil      = Shin::AST::Symbol.new(t, 'nil')
          arguments = Shin::AST::Symbol.new(t, 'arguments')
          rhs = Shin::AST::List.new(t, Hamster.vector(apply, vector, _nil, arguments))

          @builder.into(fn.body, :statement) do
            destructure(lhs, rhs)
          end
        else
          args.inner.each do |arg|
           fn.params << make_ident(arg.value)
          end
        end

        recursive = body.any? { |x| contains_recur?(x) }
        if recursive
          t = body.first.token
          bindings = []
          scope = Scope.new

          args.inner.each do |arg|
            sym = Shin::AST::Symbol.new(t, arg.value)
            bindings += [sym, sym]
          end

          @builder.with_scope(scope) do
            @builder.into(fn.body, :return) do
              translate_loop_inner(bindings, body)
            end
          end
        else
          trbody(body, fn.body)
        end
      end

      return fn
    end

    def translate_fn_inner_multi(variants, name: nil)
      fn = FunctionExpression.new(name ? make_ident(name) : nil)
      arity_cache = {}
      variadic_arity = -1

      max_arity = 0
      name_candidate = nil

      @builder.into(fn, :statement) do
        variants.each do |variant|
          matches?(variant.inner, FN_PATTERN) do |_, args, body|
            ifn = translate_fn_inner(args, body)

            arity = if args.inner.any? { |x| x.sym?('&') }
                      variadic_arity = args.inner.take_while { |x| !x.sym?('&') }.count
                      -1
                    else
                      args.inner.length
                    end

            if arity > max_arity
              name_candidate = args.inner
            end
            tmp = fresh(name ? name : "anon")
            ser!("Can't redefine arity #{arity}", variant) if arity_cache.has_key?(arity)
            arity_cache[arity] = tmp
            decl = make_decl(tmp, ifn)
            @builder << decl
          end or ser!("Invalid function variant", variant)
        end

        numargs = MemberExpression.new(make_ident('arguments'), make_ident('length'), false)
        sw = SwitchStatement.new(numargs)

        arg_names = []
        name_candidate.take_while { |x| !x.sym?('&') }.each do |x|
          arg_names << (x.sym? ? x.value : fresh('p'))
        end

        if variadic_arity >= 0
          arg_names << 'var_args'

          max_arity = arity_cache.keys.max
          if max_arity > variadic_arity
            ser!("Can't have fixed arity #{max_arity} more than variadic arity #{variadic_arity}", variants)
          end
        end

        arg_names.each do |arg_name|
          id = make_ident(arg_name)
          fn.params << id 
        end

        arity_cache.each do |arity, tmp|
          caze = SwitchCase.new(arity == -1 ? nil : make_literal(arity))

          if arity == -1
            mexp = MemberExpression.new(make_ident(tmp), Identifier.new('apply'), false)
            call = CallExpression.new(mexp)
            call << Identifier.new('this')
            call << Identifier.new('arguments')
          else
            mexp = MemberExpression.new(make_ident(tmp), Identifier.new('call'), false)
            call = CallExpression.new(mexp)
            call << Identifier.new('this')
            (0...arity).each do |i|
              call << make_ident(arg_names[i])
            end
          end
          caze << ReturnStatement.new(call)
          sw << caze
        end

        @builder << sw

        text = make_literal("Invalid arity: ")

        msg = BinaryExpression.new('+', text, numargs)
        thr = ThrowStatement.new(msg)
        @builder << thr
      end

      return fn
    end

    def translate_callchain(rest)
      curr = rest.first
      forms = rest.drop(1)

      until forms.empty?
        form = forms.first
        forms = forms.drop(1)

        ser!("Expected list in call chain", form) unless form.list?

        dot = Shin::AST::Symbol.new(form.token, ".")
        curr = Shin::AST::List.new(form.token, form.inner.insert(1, curr).insert(0, dot))
      end

      tr(curr)
    end

    #########################
    # Weapons of mass translation
    #########################

    def treach(list)
      list.each do |el|
        tr(el)
      end
    end

    def trbody(body, block)
      last_index = body.length - 1
      
      @builder.into(block, :statement) do
        body.each_with_index do |expr, i|
          if last_index == i
            @builder.into(block, :return) { tr(expr) }
          else
            tr(expr)
          end
        end
      end
    end

    def tr(expr)
      case expr
      when Shin::AST::Symbol
        if @quoting
          lit = make_literal(expr.value)
          @builder << CallExpression.new(make_ident("symbol"), [lit])
        else
          if expr.value == 'nil'
            @builder << make_literal(nil)
          else
            @builder << make_ident(expr.value)
          end
        end
        nil
      when Shin::AST::RegExp
        lit = make_literal(expr.value)
        @builder << NewExpression.new(make_ident("js/RegExp"), [lit])
        nil
      when Shin::AST::Literal
        @builder << make_literal(expr.value)
        nil
      when Shin::AST::Deref
        t = expr.token
        els = Hamster.vector(Shin::AST::Symbol.new(t, "deref"), expr.inner)
        tr(Shin::AST::List.new(t, els))
        nil
      when Shin::AST::Quote, Shin::AST::SyntaxQuote
        # TODO: find a less terrible solution.
        begin
          @quoting = true
          tr(expr.inner)
        ensure
          @quoting = false
        end
        nil
      when Shin::AST::Vector
        first = expr.inner.first
        if first && first.sym?('$')
          @builder.into!(ArrayExpression.new) do
            treach(expr.inner.drop(1))
          end
        else
          @builder.into!(CallExpression.new(make_ident('vector'))) do
            treach(expr.inner)
          end
        end
        nil
      when Shin::AST::Set
        @builder.into!(CallExpression.new(make_ident('hash-set'))) do
          treach(expr.inner)
        end
        nil
      when Shin::AST::Map
        first = expr.inner.first
        if first && first.sym?('$')
          list = expr.inner.drop(1)
          props = []
          list.each_slice(2) do |pair|
            key, val = pair
            props << Property.new(as_expr(key), as_expr(val))
          end
          @builder << ObjectExpression.new(props)
        else
          unless expr.inner.count.even?
            ser!("Map literal requires even number of forms", expr)
          end
          @builder.into!(CallExpression.new(make_ident('hash-map'))) do
            treach(expr.inner)
          end
        end
        nil
      when Shin::AST::Keyword
        lit = make_literal(expr.value)
        @builder << CallExpression.new(make_ident('keyword'), [lit])
        nil
      when Shin::AST::List
        if @quoting
          call = CallExpression.new(make_ident("list"))
          @builder.into(call, :expression) do
            treach(expr.inner)
          end
          @builder << call
          nil
        else
          translate_listform(expr)
        end
      when Shin::AST::Unquote
        ser!("Invalid usage of unquoting outside of a quote", expr) unless @quoting
        call = CallExpression.new(make_ident('--unquote'))

        @builder.into(call, :expression) do
          spliced = false
          inner = expr.inner
          if Shin::AST::Deref === inner
            spliced = true
            inner = inner.inner
          end

          begin
            @quoting = false
            tr(inner)
          ensure
            @quoting = true
          end
          @builder << Literal.new(spliced)
        end

        @builder << call
        nil
      when Shin::AST::Closure
        translate_closure(expr)
      else
        ser!("Unknown expr form #{expr}", expr)
      end
    end

    def translate_listform(expr)
      list = expr.inner
      first = list.first

      unless first
        @builder << CallExpression.new(make_ident("list"))
        return
      end

      if first.sym?
        handled = true

        rest = list.drop(1)
        name = first.value

        # JS interop
        case
        when name.start_with?('.-')
          # field access
          propname = name[2..-1]
          if propname.empty?
            sym = rest.first
            ser!("Expected symbol", sym) unless sym.sym?
            propname = sym.value
            rest = rest.drop(1)
          end

          property = Identifier.new(propname)
          object = as_expr(rest[0])
          @builder << MemberExpression.new(object, property, false)
        when name == '..'
          translate_callchain(rest)
        when name.start_with?('.')
          # method call
          propname = name[1..-1]
          if propname.empty?
            sym = rest.first
            ser!("Expected symbol", sym) unless sym.sym?
            propname = sym.value
            rest = rest.drop(1)
          end

          property = Identifier.new(propname)
          object = as_expr(rest[0])
          mexp = MemberExpression.new(object, property, false)

          @builder.into!(CallExpression.new(mexp)) do
            treach(rest.drop(1))
          end
        when name.end_with?('.')
          # instanciation
          type_name = name[0..-2]
          inst = NewExpression.new(make_ident(type_name))
          @builder.into!(inst) do
            treach(list.drop(1))
          end
        else
          handled = false
        end

        return if handled
        handled = true

        # special forms
        case name
        when "<", ">", "<=", ">=", "==", "==="
          translate_comp(first, rest)
        when "and", "or"
          translate_logic(first, rest)
        when "let"
          translate_let(rest)
        when "fn"
          translate_fn(rest)
        when "do"
          translate_do(rest)
        when "if"
          translate_if(rest)
        when "cond"
          translate_cond(rest)
        when "condp"
          translate_condp(rest)
        when "loop"
          translate_loop(rest)
        when "recur"
          anchor = nil
          begin
            anchor = @builder.anchor
          rescue
            ser!("Recur with no anchor: #{expr}", first)
          end

          values = list.drop(1)
          block = BlockStatement.new
          @builder << block

          @builder.into(block, :statement) do
            t = expr.token
            tmps = []

            # TODO: fix that. cf #56
            # lhs_vec = Shin::AST::Vector.new(t, anchor.bindings)
            # rhs_vec = Shin::AST::Vector.new(t, values)
            # destructure(lhs_vec, rhs_vec)

            anchor.bindings.each_with_index do |lhs, i|
              rhs = values[i]
              ser!("Missing value in recur", values) unless rhs
              tmp = Shin::AST::Symbol.new(t, fresh("G__"))
              destructure(tmp, rhs)
              tmps << tmp
            end

            anchor.bindings.each_with_index do |lhs, i|
              tmp = tmps[i]
              destructure(lhs, tmp, :mode => :assign)
            end
            ass = AssignmentExpression.new(anchor.sentinel, make_literal(true))
            @builder << ass
          end
        when "set!"
          property, val = rest
          @builder << AssignmentExpression.new(as_expr(property), as_expr(val))
        when "aset"
          object, property, val = rest
          mexpr = MemberExpression.new(as_expr(object), as_expr(property), true)
          @builder << AssignmentExpression.new(mexpr, as_expr(val))
        when "aget"
          object = rest.first
          props = rest.drop(1)

          curr = as_expr(object)
          until props.empty?
            prop = props.first; props = props.drop(1)
            curr = MemberExpression.new(curr, as_expr(prop), true)
          end
          @builder << curr
        when "instance?"
          r, l = rest
          @builder << BinaryExpression.new('instanceof', as_expr(l), as_expr(r))
        when "throw"
          arg = rest.first
          @builder << ThrowStatement.new(as_expr(arg))
        when "*js-uop"
          op, arg = rest
          @builder << UnaryExpression.new(op.value, as_expr(arg))
        when "*js-bop"
          op, l, r = rest
          @builder << BinaryExpression.new(op.value, as_expr(l), as_expr(r))
        else
          handled = false
        end

        return if handled
      end

      # if we reached here, it's not a special form,
      # just a regular function call
      ifn = as_expr(first)
      mexp = MemberExpression.new(ifn, make_ident('call'), false)
      @builder.into!(CallExpression.new(mexp)) do
        @builder << make_literal(nil)
        treach(list.drop(1))
      end
      nil
    end

    ##################
    # Variable declaration helpers
    ##################

    # declare or assign, depending on mode
    def decline(lhs, rhs, mode)
      rhs = as_expr(rhs) if Shin::AST::Node === rhs

      case mode
      when :declare
        tmp = fresh("#{lhs.value}")
        @builder.declare(lhs.value, tmp)
        @builder << make_decl(tmp, rhs)
      when :assign
        @builder << AssignmentExpression.new(make_ident(lhs.value), rhs)
      else raise "Invalid mode: #{mode}"
      end
    end

    # Exploratory helpers

    def contains_recur?(ast)
      case ast
      when Shin::AST::List
        return false if ast.inner.empty?

        first = ast.inner.first
        if first.sym?
          case first.value
          when "recur"
            return true
          when "fn", "loop"
            # new top-recursion points, those recur's don't concern us.
            return false
          end
        end

        ast.inner.any? { |x| contains_recur?(x) }
      when Shin::AST::Sequence
        ast.inner.any? { |x| contains_recur?(x) }
      else
        false
      end
    end

    # JST helpers

    def make_decl(name, expr)
      expr = as_expr(expr)    if     Shin::AST::Node       === expr
      name = make_ident(name) unless Shin::JST::Identifier === name

      decl = VariableDeclaration.new
      dtor = VariableDeclarator.new(name, expr)
      decl.declarations << dtor
      decl
    end

    def make_literal(id)
      Literal.new(id)
    end

    def make_ident(id)
      matches = /^([^\/]+)[\/](.*)?$/.match(id)
      if matches
        ns, name = matches.to_a.drop(1)
        case ns
        when "js"
          Identifier.new(name)
        else
          MemberExpression.new(make_ident(ns), make_ident(name), false)
        end
      else
        aka = @builder.lookup(id)
        if aka
          # debug "Resolved #{id} => #{aka}"
          matches = /^([^\/]+)\/(.*)?$/.match(aka)
          if matches
            obj, prop = matches.to_a.drop(1)
            MemberExpression.new(make_ident(obj), Identifier.new(mangle(prop)), false)
          else
            Identifier.new(mangle(aka))
          end
        else
          Identifier.new(mangle(id))
        end
      end
    end

    def debug(*args)
      puts("[TRANSLATOR] #{args.join(" ")}") if DEBUG
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
