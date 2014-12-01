
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
              when "declare"
                translate_declare(rest)
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

    def is_catch?(node)
      node.list? && node.inner.first && node.inner.first.sym?("catch")
    end

    def translate_try(list)
      exprs   = list.take_while { |x| !is_catch?(x) }
      clauses = list.drop_while { |x| !is_catch?(x) }
      ser!("All 'catch' clauses must be at the end of a try form.", list) unless clauses.all? { |x| is_catch?(x) }

      # TODO: support finally
      # TODO: support expression mode
      
      mode = @builder.mode
      support = case mode
                when :expression
                  FunctionExpression.new
                when :statement, :return
                  BlockStatement.new
                else
                  raise "try in unknown mode: #{mode}"
                end

      trie = TryStatement.new
      case mode
      when :expression, :return
        trbody(exprs, trie.block)
      when :statement
        @builder.into(trie.block, :statement) do
          treach(exprs)
        end
      end

      exarg = Identifier.new(fresh('ex'))
      pitch = CatchClause.new(exarg)
      trie.handlers << pitch

      t = list.first.token
      exsym = Shin::AST::Symbol.new(t, exarg.name)
      condp_sym = Shin::AST::Symbol.new(t, "condp")
      inst_sym = Shin::AST::Symbol.new(t, "instance?")
      condp_vec = Hamster.vector(condp_sym, inst_sym, exsym)

      clauses.each do |clause|
        t = clause.token

        args = clause.inner.drop(1)
        etype = args.first; args = args.drop(1)
        param = args.first; args = args.drop(1)
        cbody = args.first

        condp_vec <<= etype

        binds_vec = Hamster.vector(param, exsym)
        let_binds = Shin::AST::Vector.new(t, binds_vec)

        let_sym = Shin::AST::Symbol.new(t, "let")
        let_vec = Hamster.vector(let_sym, let_binds, cbody)
        condp_vec <<= Shin::AST::List.new(t, let_vec)
      end

      condp = Shin::AST::List.new(t, condp_vec)

      case mode
      when :expression, :return
        @builder.into(pitch, :return) do
          tr(condp)
        end
      when :statement
        @builder.into(pitch, :statement) do
          tr(condp)
        end
      end

      support << trie

      case mode
      when :expression
        @builder << CallExpression.new(support)
      else
        @builder << support
      end
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
        inner = Hamster.vector(fi, cond, form)
        if rec = unwrap_cond(list)
          inner <<= rec
        end
        Shin::AST::List.new(t, inner)
      else
        nil
      end
    end

    def translate_condp(list)
      # TODO: support :>>
      
      return if list.size <= 2

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
        protocol_obj = ObjectExpression.new
        fullname = mangle("#{@mod.ns}/#{name.value}")
        fullname_property = Property.new(make_ident("protocol-name"), make_literal(fullname))
        protocol_obj.properties << fullname_property

        protocol_name = name.value
        ex = make_ident("exports/#{protocol_name}")
        ass = AssignmentExpression.new(ex, protocol_obj)
        @builder << make_decl(Identifier.new(protocol_name), ass)

        sigs.each do |sig|
          meth_name = sig.inner.first

          arg_lists = sig.inner.drop(1)
          arg_lists.each do |arg_list|
            res!("Expected argument list", arg_list) unless arg_list.vector?
          end

          fn = if arg_lists.length == 1
                 translate_protocol_simple_fun(protocol_name, meth_name, arg_lists.first)
               else
                 translate_protocol_multi_fun(protocol_name, meth_name, arg_lists)
               end
          ex = make_ident("exports/#{meth_name}")
          ass = AssignmentExpression.new(ex, fn)
          @builder << make_decl(make_ident(meth_name.value), ass)
        end
      end or ser!("Invalid defprotocol form", list)
    end

    def translate_protocol_simple_fun(protocol_name, name, arg_list)
      arity = arg_list.inner.length
      fn = FunctionExpression.new(nil)
      arguments = make_ident('arguments')
      this_access = MemberExpression.new(arguments, make_literal(0), true)

      slot_aware_name = "#{name.value}$arity#{arg_list.inner.length}"

      meth_acc = MemberExpression.new(this_access, make_ident(slot_aware_name), false)
      
      # err if not implemented
      # TODO: remove code duplication with translate_protocol_multi_fun
      slot_null = BinaryExpression.new("==", meth_acc, make_literal(nil))
      if_notimpl = IfStatement.new(slot_null)
      err_message = "Unimplemented protocol function #{protocol_name}.#{name} for arity #{arity}"
      err = NewExpression.new(Identifier.new("Error"), [make_literal(err_message)])
      if_notimpl.consequent << ThrowStatement.new(err)
      fn.body << if_notimpl

      # TODO: don't always use apply, just relay args if non-variadic
      apply_acc = MemberExpression.new(meth_acc, make_ident('apply'), false)
      first_arg = MemberExpression.new(arguments, make_literal(0), true)
      meth_call = CallExpression.new(apply_acc)
      meth_call.arguments << first_arg
      meth_call.arguments << make_ident('arguments')
      fn.body << ReturnStatement.new(meth_call)

      return fn
    end

    def translate_protocol_multi_fun(protocol_name, name, arg_lists)
      fn = FunctionExpression.new(nil)
      arguments = make_ident('arguments')
      this_access = MemberExpression.new(arguments, make_literal(0), true)

      numargs = MemberExpression.new(arguments, make_ident('length'), false)
      sw = SwitchStatement.new(numargs)
      fn << sw

      arg_lists.each do |arg_list|
        arity = arg_list.inner.length
        slot_aware_name = "#{name.value}$arity#{arity}"

        caze = SwitchCase.new(variadic_args?(arg_list) ?  nil : make_literal(arity))
        sw.cases << caze

        slot_id = make_ident(slot_aware_name)
        meth_acc = MemberExpression.new(this_access, slot_id, false)

        # err if not implemented
        # TODO: remove code duplication with translate_protocol_simple_fun
        slot_null = BinaryExpression.new("==", meth_acc, make_literal(nil))
        if_notimpl = IfStatement.new(slot_null)
        err_message = "Unimplemented protocol function #{protocol_name}.#{name} for arity #{arity}"
        err = NewExpression.new(Identifier.new("Error"), [make_literal(err_message)])
        if_notimpl.consequent << ThrowStatement.new(err)
        caze << if_notimpl

        # TODO: don't always use apply, just relay args if non-variadic
        apply_acc = MemberExpression.new(meth_acc, make_ident('apply'), false)
        first_arg = MemberExpression.new(arguments, make_literal(0), true)
        meth_call = CallExpression.new(apply_acc)
        meth_call.arguments << first_arg
        meth_call.arguments << make_ident('arguments')
        caze << ReturnStatement.new(meth_call)
      end

      return fn
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

        block << make_decl(name.value, ctor)

        prototype_mexpr = MemberExpression.new(make_ident(name.value), make_ident("prototype"), false)

        # naked methods won't have arity suffixes or whatever.
        naked = false

        @builder.into(block, :statement) do
          body.each do |limb|
            case
            when limb.list?
              id = limb.inner.first
              fn = nil

              type_scope = Scope.new

              args_len = -1

              @builder.with_scope(type_scope) do
                self_name = fresh("self")
                fields.inner.each do |field|
                  next if field.meta?  # FIXME: woooooooooo #28
                  type_scope[field.value] = "#{self_name}/#{field.value}"
                end if fields

                fn = nil
                matches?(limb.inner.drop(1), FN_PATTERN) do |name, args, body|
                  args_len = args.inner.length
                  fn = translate_fn_inner(args, body, :name => (name ? name.value : nil))
                end or ser!("Invalid fn form in deftype: #{limb}", list)

                self_decl = VariableDeclaration.new
                self_dtor = VariableDeclarator.new(make_ident(self_name), make_ident("this"))
                self_decl.declarations << self_dtor
                fn.body.body.unshift(self_decl)
              end

              raise "Internal error" if args_len == -1
              arity_aware_slot_name = naked ? id.value : "#{id.value}$arity#{args_len}"
              slot = MemberExpression.new(prototype_mexpr, make_ident(arity_aware_slot_name), false)
              ass = AssignmentExpression.new(slot, fn)
              @builder << ExpressionStatement.new(ass)
            when limb.sym?
              # listing a protocol the type implements

              # new way
              proto = make_ident(limb.value)
              protocol_name = MemberExpression.new(proto, make_ident("protocol-name"), false)
              slot = MemberExpression.new(prototype_mexpr, protocol_name, true)
              ass = AssignmentExpression.new(slot, make_literal(true))
              @builder << ass

              # Object is special, cf. #76
              if limb.value == "Object"
                naked = true
              else
                naked = false
              end

              # IFn is special, cf. #50
              if limb.value == "IFn"
                fn = FunctionExpression.new(nil)
                invoke_apply = MemberExpression.new(make_ident("-invoke"), Identifier.new("apply"), false)
                arguments = Identifier.new("arguments")
                this_id = Identifier.new("this")
                array_proto = MemberExpression.new(Identifier.new("Array"), Identifier.new("prototype"), false)
                slice = MemberExpression.new(array_proto, Identifier.new("slice"), false)
                slice_apply = MemberExpression.new(slice, Identifier.new("call"), false)
                sliced_args = CallExpression.new(slice_apply, [arguments, make_literal(1)])

                this_array = ArrayExpression.new([this_id])
                this_concat = MemberExpression.new(this_array, Identifier.new("concat"), false)
                concat = CallExpression.new(this_concat, [sliced_args])

                apply_args = [make_literal(nil),
                              concat]
                apply_call = CallExpression.new(invoke_apply, apply_args)
                fn << ReturnStatement.new(apply_call)
                slot = MemberExpression.new(prototype_mexpr, Identifier.new("call"), false)
                ass = AssignmentExpression.new(slot, fn)
                @builder << ExpressionStatement.new(ass)
              end
            else
              ser!("Unrecognized thing in deftype", limb)
            end
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

    def translate_declare(list)
      list.each do |el|
        next if el.meta?
        ser!("Expected symbol in declare", el) unless el.sym?
        ex = make_ident("exports/#{el.value}")
        ass = AssignmentExpression.new(ex, Identifier.new("null"))
        @builder << make_decl(make_ident(el.value), ass)
      end
    end

    DEF_PATTERN             = ":sym :expr*".freeze
    DEF_WITH_DOC_PATTERN    = ":str :expr".freeze
    DEF_WITHOUT_DOC_PATTERN = ":expr".freeze

    def translate_def(list)
      matches?(list, DEF_PATTERN) do |name, rest|
        init = nil

        case
        when matches?(rest, DEF_WITH_DOC_PATTERN)
          doc, expr = rest
          init = as_expr(expr)
        when matches?(rest, DEF_WITHOUT_DOC_PATTERN)
          expr = rest.first
          init = as_expr(expr)
        else
          ser!("Invalid def form", list)
        end

        ex = make_ident("exports/#{name}")
        ass = AssignmentExpression.new(ex, init)
        @builder << make_decl(make_ident(name.value), ass)
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

    FN_PATTERN = ":sym? [:expr*] :expr*".freeze

    def translate_fn(list)
      matches?(list, FN_PATTERN) do |name, args, body|
        fn = translate_fn_inner(args, body, :name => (name ? name.value : nil))
        @builder << fn
      end or ser!("Invalid fn form: #{list.join(" ")}", list)
      nil
    end

    def variadic_args?(args)
      args.inner.any? { |x| x.sym?('&') }
    end

    def translate_variadic_fn_inner(args, body, name: nil)
      t = args.inner.first.token

      fixed_args    = args.inner.take_while { |x| !x.sym?('&') }
      variadic_args = args.inner.drop(fixed_args.count + 1)
      ser!("Internal error: Invalid variadic state", body) unless variadic_args.count == 1
      variadic_arg = variadic_args.first

      fn_sym = AST::Symbol.new(t, "fn")
      let_sym = AST::Symbol.new(t, "let")

      arg_vec = Hamster.vector
      arg_names = []
      fixed_args.each do |arg|
        name = if arg.sym?
                 arg.value
               else
                 fresh("darg")
               end
        arg_names << name
        arg_vec <<= arg
      end
      variadic_name = if variadic_arg.sym?
                        variadic_arg.value
                      else
                        fresh("varg")
                      end
      variadic_sym = AST::Symbol.new(t, variadic_name)

      arg_vec <<= variadic_sym
      inner_fn_args = AST::Vector.new(t, arg_vec)
      inner_fn_vec = Hamster.vector(fn_sym, inner_fn_args)
      body.each do |child|
        inner_fn_vec <<= child
      end
      inner_fn = AST::List.new(t, inner_fn_vec)

      outer_arg_vec = Hamster.vector
      arg_names.each do |name|
        outer_arg_vec <<= AST::Symbol.new(t, name)
      end
      outer_args = AST::Vector.new(t, outer_arg_vec)

      # only prepare varargs if given more than fixed args
      if_sym = AST::Symbol.new(t, "if")
      nil_sym = AST::Symbol.new(t, "nil")

      num_fixed_args = AST::Number.new(t, fixed_args.length)

      gt_sym = AST::Symbol.new(t, ">")
      arglen_vec = Hamster.vector(AST::Symbol.new(t, ".-length"),
                                  AST::Symbol.new(t, "arguments"))
      arglen = AST::List.new(t, arglen_vec)
      arg_comp_vec = Hamster.vector(gt_sym, arglen, num_fixed_args)
      arg_comp = AST::List.new(t, arg_comp_vec)

      proto_vec = Hamster.vector(AST::Symbol.new(t, ".-prototype"),
                                 AST::Symbol.new(t, "Array"))
      proto = AST::List.new(t, proto_vec)
      slice_fn_vec = Hamster.vector(AST::Symbol.new(t, ".-slice"), proto)
      slice_fn = AST::List.new(t, slice_fn_vec)
      rest_of_args_vec = Hamster.vector(AST::Symbol.new(t, ".call"),
                                        slice_fn,
                                        AST::Symbol.new(t, "arguments"),
                                        num_fixed_args)
      rest_of_args = AST::List.new(t, rest_of_args_vec)

      vector_apply_vec = Hamster.vector(AST::Symbol.new(t, ".apply"),
                                        AST::Symbol.new(t, "vector"),
                                        nil_sym,
                                        rest_of_args)
      vector_apply = AST::List.new(t, vector_apply_vec)

      if_enough_args_vec = Hamster.vector(if_sym, arg_comp, vector_apply, nil_sym)
      if_enough_args = AST::List.new(t, if_enough_args_vec)
      varargs_prepared = if_enough_args

      inner_sym = AST::Symbol.new(t, "inner")
      bindings_vec = Hamster.vector(inner_sym, inner_fn, variadic_sym, varargs_prepared)
      bindings = AST::Vector.new(t, bindings_vec)

      inner_call_vec = Hamster.vector(inner_sym)
      arg_names.each do |name|
        inner_call_vec <<= AST::Symbol.new(t, name)
      end
      inner_call_vec <<= variadic_sym
      inner_call = AST::List.new(t, inner_call_vec)
      let_vec = Hamster.vector(let_sym, bindings, inner_call)
      outer_body = AST::List.new(t, let_vec)

      if DEBUG
        debug "=========================================================="
        debug "Original: \n\n(fn #{args} #{body.join(" ")})\n\n"
        debug "Wrapped:\n\n(fn #{outer_args} #{outer_body}\n\n"
      end

      return translate_fn_inner(outer_args, [outer_body], :name => name)
    end

    def translate_fn_inner(args, body, name: nil)
      if variadic_args?(args)
        return translate_variadic_fn_inner(args, body, :name => name)
      end

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

    def translate_chain(rest)
      curr = rest.first
      forms = rest.drop(1)

      until forms.empty?
        form = forms.first; forms = forms.drop(1)

        case form
        when Shin::AST::List
          dot = Shin::AST::Symbol.new(form.token, ".")
          curr = Shin::AST::List.new(form.token, form.inner.insert(1, curr).insert(0, dot))
        when Shin::AST::Symbol
          ser!("Expected access in chain") unless form.value.start_with?("-")
          dod = Shin::AST::Symbol.new(form.token, ".-")
          prop = Shin::AST::Symbol.new(form.token, form.value[1..-1])
          curr = Shin::AST::List.new(form.token, Hamster.vector(dod, prop, curr))
        else
          ser!("Expected list or access in chain", form)
        end
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
        if @quoting
          @builder << CallExpression.new(make_ident('--quoted-re'), [lit])
        else
          @builder << NewExpression.new(make_ident("js/RegExp"), [lit])
        end
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
        ser!("Invalid usage of unquoting outside of a quote: #{expr}", expr) unless @quoting
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
        ser!("Closures are supposed to be gone by the time we reach the translator", expr)
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

          property = Identifier.new(mangle(propname))
          object = as_expr(rest[0])
          @builder << MemberExpression.new(object, property, false)
        when name == '..'
          translate_chain(rest)
        when name =~ /^[.][A-Za-z_]*$/
          # method call
          propname = name[1..-1]
          if propname.empty?
            sym = rest.first
            ser!("Expected symbol", sym) unless sym.sym?
            propname = sym.value
            rest = rest.drop(1)
          end

          property = Identifier.new(mangle(propname))
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
        when "do"
          translate_do(rest)
        when "if"
          translate_if(rest)
        when "try"
          translate_try(rest)
        when "catch"
          # it's normalled all handled in translate_try
          ser!("Unexpected 'catch'", expr)
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
          block = RecurBlockStatement.new
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
          object = rest.first
          props = rest.drop(1)

          curr = as_expr(object)
          while props.size > 1
            prop = props.first; props = props.drop(1)
            curr = MemberExpression.new(curr, as_expr(prop), true)
          end
          val = props.first
          @builder << AssignmentExpression.new(curr, as_expr(val))
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
          if name == "fn" && !rest.empty?
            translate_fn(rest)
          else
            handled = false
          end
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
      "T__#{prefix}#{@seed += 1}"
    end
  end
end
