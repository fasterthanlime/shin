
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
        [Identifier.new('this')])
      define_call.arguments << bound_factory
      load_shim.body << ExpressionStatement.new(define_call)

      factory = FunctionExpression.new
      requires.each do |req|
        next if req.macro? && !@mod.macro?
        factory.params << make_ident(req.slug)
      end

      shim_call = CallExpression.new(load_shim)
      shim_call.arguments << ThisExpression.new
      shim_call.arguments << factory
      program.body << ExpressionStatement.new(shim_call)

      body = factory.body
      use_strict = make_literal("use strict");
      body << ExpressionStatement.new(use_strict)

      requires.each do |req|
        next if req.macro? && !@mod.macro?
        if req.as_sym != req.slug
          body << make_decl(make_ident(req.as_sym), make_ident(req.slug))
        end
      end

      top_scope = CompositeScope.new

      @mod.requires.each do |req|
        next if req.macro? && !@mod.macro?
        if req.all?
          unless req.js?
            dep = @compiler.modules[req]
            raise Shin::Error, "Couldn't find req #{req.slug}" unless dep
            top_scope.attach!(FilteredScope.new(req, dep))
          end
        elsif !req.refer.empty?
          ref_scope = Scope.new
          req.refer.each do |d|
            ref_scope[d] = "#{req.ns}/#{d}"
          end
          top_scope.attach!(ref_scope)
        end
      end

      @builder.with_scope(top_scope) do
        @builder.into(body, :statement) do
          trmain(ast)
        end
      end

      @mod.jst = program
    end

    def trmain(ast)
      ast.each do |node|
        case node
        when AST::List
          list = node.inner.to_a
          first = list.first
          if first && first.sym?
            rest = list.drop(1)
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

    protected

    EXPORT_PATTERN = ":sym :sym?".freeze

    def destructuring_needed?(lhs)
      !lhs.sym? || lhs.sym?('&')
    end

    def as_expr(expr)
      @builder.single do
        tr(expr)
      end or ser!("Expected expression from #{expr}, got nothing.", expr)
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
      when AST::Vector
        destructure_vector(lhs.inner, rhs, mode)
      when AST::Map
        destructure_map(lhs.inner, rhs, mode)
      when AST::Symbol
        decline(lhs, rhs, mode)
      else
        ser!("Invalid let form: first binding form should be a symbol or collection, instead, got #{lhs.class}", lhs)
      end
    end

    def destructure_vector(inner, rhs, mode)
      done = false
      list = inner.to_a
      rhs_memo = fresh("rhsmemo")
      @builder << make_decl(rhs_memo, rhs)
      rhs_sym = AST::Symbol.new(rhs.token, rhs_memo)
      rhs_id = ident(rhs_memo)

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
              part = CallExpression.new(ident('nthnext'), [rhs_id, make_literal(i)])
              @builder << make_decl(rest.value, part)
            end
          else
            part = CallExpression.new(ident('nth'), [rhs_id, make_literal(i)])
            if name.sym?
              @builder << make_decl(name.value, part)
            else
              part_memo = fresh("partmemo")
              @builder << make_decl(part_memo, part)
              destructure(name, AST::Symbol.new(name.token, part_memo))
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
      rhs_sym = AST::Symbol.new(rhs.token, rhs_memo)
      rhs_id = ident(rhs_memo)

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
              when 'keys' then AST::Keyword.new(sym.token, sym.value)
              when 'strs' then AST::String.new(sym.token, sym.value)
              when 'syms'
                s = AST::Symbol.new(sym.token, sym.value)
                AST::Quote.new(sym.token, s)
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
          part = CallExpression.new(ident('get'), [rhs_id, as_expr(map_key)])
          if name.sym?
            if alt = alt_map[name.value]
              part.arguments << as_expr(alt)
            end
            decline(name, part, mode)
          else
            part_memo = fresh("partmemo")
            @builder << make_decl(part_memo, part)
            destructure(name, AST::Symbol.new(name.token, part_memo))
          end
        end
      end
    end

    LET_PATTERN = "[] :expr*".freeze

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
      matches = matches?(list, LET_PATTERN)
      ser!("Invalid let form", list) unless matches

      bindings, body = matches
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
               @builder.recipient
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
      nil
    end

    def translate_do(list)
      case @builder.mode
      when :expression
        anon = FunctionExpression.new
        trbody(list, anon.body)
        @builder << CallExpression.new(anon)
      when :statement
        treach(list)
      when :return
        trbody(list, @builder.recipient)
      else
        raise "do in unknown builder mode: #{@builder.mode}"
      end
      nil
    end

    def is_catch?(node)
      node.list? && node.inner.first && node.inner.first.sym?("catch")
    end

    def is_finally?(node)
      node.list? && node.inner.first && node.inner.first.sym?("finally")
    end

    def translate_try(list)
      state = :expr
      exprs = []; clauses = []; final = nil

      i = 0; len = list.length
      while i < len
        el = list[i]
        case true
        when is_catch?(el)
          case state
          when :expr, :catch
            clauses << el
            state = :catch
          else
            ser!("Unexpected catch clause", el)
          end
        when is_finally?(el)
          case state
          when :expr, :catch
            if final.nil?
              final = el
            else
              ser!("Duplicate finally block", el)
            end
            state = :finally
          end
        else
          case state
          when :expr
            exprs << el
          else
            ser!("In try, expected catch or finally", el)
          end
        end
        i += 1
      end
      
      mode = @builder.mode
      support = case mode
                when :expression
                  fn = FunctionExpression.new
                  @builder << CallExpression.new(fn)
                  fn
                when :statement, :return
                  @builder.recipient
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

      unless clauses.empty?
        exarg = Identifier.new(fresh('ex'))
        pitch = CatchClause.new(exarg)
        trie.handlers << pitch

        t = list.first.token
        exsym = AST::Symbol.new(t, exarg.name)
        condp_sym = AST::Symbol.new(t, "condp")
        inst_sym = AST::Symbol.new(t, "instance?")
        condp_vec = Hamster.vector(condp_sym, inst_sym, exsym)

        clauses.each do |clause|
          t = clause.token

          args = clause.inner.drop(1)
          etype = args.first; args = args.drop(1)
          param = args.first; args = args.drop(1)
          cbody = args.first

          condp_vec <<= etype

          binds_vec = Hamster.vector(param, exsym)
          let_binds = AST::Vector.new(t, binds_vec)

          let_sym = AST::Symbol.new(t, "let")
          let_vec = Hamster.vector(let_sym, let_binds, cbody)
          condp_vec <<= AST::List.new(t, let_vec)
        end

        condp = AST::List.new(t, condp_vec)

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
      end

      # handle finally
      if final
        final_block = BlockStatement.new;
        final_body = final.inner.drop(1)
        @builder.into(final_block, :statement) do
          treach(final_body)
        end
        trie.finalizer = final_block
      end

      support << trie
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

        if cond.kw?('else')
          ser!(":else directive must be in last position", cond) unless list.empty?
          form
        else
          t = cond.token
          fi = AST::Symbol.new(t, "if")
          inner = Hamster.vector(fi, cond, form)
          if rec = unwrap_cond(list)
            inner <<= rec
          end
          AST::List.new(t, inner)
        end
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
          list[i] = List.new(lhs.token, inner)
        end
        i += 2
      end

      tr(unwrap_cond(list))
    end

    def translate_this_as(list)
      aka = list.first
      body = list.drop(1)

      scope = Scope.new

      tmp = ident(fresh(aka.value))
      @builder << make_decl(tmp, Identifier.new("this"))
      scope[aka.value] = tmp.name

      @builder.with_scope(scope) do
        treach(body)
      end
    end

    VALID_IDENT_RE = /^[A-Za-z_\$]+$/

    def valid_ident?(name)
      name =~ VALID_IDENT_RE
    end

    def translate_aset(rest)
      object = rest.first
      props = rest.drop(1)

      curr = as_expr(object)
      while props.size > 1
        prop = props.first; props = props.drop(1)
        if AST::String === prop && valid_ident?(prop.value)
          curr = MemberExpression.new(curr, make_ident(prop.value), false)
        else
          curr = MemberExpression.new(curr, as_expr(prop), true)
        end
      end
      val = props.first
      @builder << AssignmentExpression.new(curr, as_expr(val))
    end

    def translate_aget(rest)
      object = rest.first
      props = rest.drop(1)

      curr = as_expr(object)
      until props.empty?
        prop = props.first; props = props.drop(1)
        if AST::String === prop && valid_ident?(prop.value)
          curr = MemberExpression.new(curr, make_ident(prop.value), false)
        else
          curr = MemberExpression.new(curr, as_expr(prop), true)
        end
      end
      @builder << curr
    end

    def translate_recur(values)
      anchor = @builder.anchor or ser!("Recur with no anchor: #{expr}", first)

      old_mode = @builder.vase.mode
      @builder.vase.mode = :statement
      tmps = []

      anchor.bindings.each_with_index do |lhs, i|
        rhs = values[i]
        ser!("Missing value in recur", values) unless rhs
        tmp = AST::Symbol.new(rhs.token, fresh("G__"))
        destructure(tmp, rhs)
        tmps << tmp
      end

      anchor.bindings.each_with_index do |lhs, i|
        tmp = tmps[i]
        destructure(lhs, tmp, :mode => :assign)
      end
      ass = AssignmentExpression.new(anchor.sentinel, make_literal(true))
      @builder << ass
      @builder.vase.mode = old_mode
    end

    LOOP_PATTERN            = "[:expr*] :expr*"

    def translate_loop(list)
      matches = matches?(list, LOOP_PATTERN)
      ser!("Invalid loop form", list) unless matches
     
      bindings, body = matches
      translate_loop_inner(bindings.inner, body)
      nil
    end

    def translate_loop_inner(bindings, body)
      scope = Scope.new
      mode = @builder.mode
      support = case @builder.mode
                when :expression
                  fn = FunctionExpression.new
                  @builder << CallExpression.new(fn)
                  fn
                when :statement, :return
                  @builder.recipient
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
    end

    DEFPROTOCOL_PATTERN     = ":sym :str? :list*".freeze

    def translate_defprotocol(list)
      matches = matches?(list, DEFPROTOCOL_PATTERN)
      ser!("Invalid defprotocol form", list) unless matches

      name, doc, sigs = matches
      protocol_obj = ObjectExpression.new
      fullname = mangle("#{@mod.ns}/#{name.value}")
      fullname_property = Property.new(ident("protocol-name"), make_literal(fullname))
      protocol_obj.properties << fullname_property

      protocol_name = name.value
      ex = make_ident("exports/#{protocol_name}")
      ass = AssignmentExpression.new(ex, protocol_obj)
      @builder << make_decl(Identifier.new(protocol_name), ass)

      sigs.each do |sig|
        meth_name = sig.inner.first.value

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
        @builder << make_decl(make_ident(meth_name), ass)
      end
    end

    def translate_protocol_simple_fun(protocol_name, name, arg_list)
      arity = arg_list.inner.length
      fn = FunctionExpression.new(name ? make_ident(name) : nil)
      arguments = Identifier.new('arguments')
      this_access = MemberExpression.new(arguments, make_literal(0), true)

      slot_aware_name = "#{name}$arity#{arg_list.inner.length}"
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
      apply_acc = MemberExpression.new(meth_acc, Identifier.new('apply'), false)
      first_arg = MemberExpression.new(arguments, make_literal(0), true)
      meth_call = CallExpression.new(apply_acc)
      meth_call.arguments << first_arg
      meth_call.arguments << Identifier.new('arguments')
      fn.body << ReturnStatement.new(meth_call)

      return fn
    end

    def translate_protocol_multi_fun(protocol_name, name, arg_lists)
      fn = FunctionExpression.new(name ? make_ident(name) : nil)
      arguments = Identifier.new('arguments')
      this_access = MemberExpression.new(arguments, make_literal(0), true)

      numargs = MemberExpression.new(arguments, Identifier.new('length'), false)
      sw = SwitchStatement.new(numargs)
      fn << sw

      arg_lists.each do |arg_list|
        arity = arg_list.inner.length
        slot_aware_name = "#{name}$arity#{arity}"

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
        meth_call.arguments << Identifier.new('arguments')
        caze << ReturnStatement.new(meth_call)
      end

      return fn
    end

    DEFTYPE_PATTERN         = ":sym :str? :vec? :expr*".freeze

    def translate_deftype(list)
      matches = matches?(list, DEFTYPE_PATTERN)
      ser!("Invalid deftype form", list) unless matches

      name, doc, fields, body = matches
      decl = VariableDeclaration.new
      dtor = VariableDeclarator.new(make_ident(name.value))

      wrapper = FunctionExpression.new
      block = wrapper.body
      dtor.init = CallExpression.new(wrapper)

      # TODO: members / params
      ctor = FunctionExpression.new

      field_names = {}

      this_id = Identifier.new('this')
      fields.inner.each do |field|
        next if field.meta?  # FIXME: woooooooooo #28

        fname = reserved?(field.value) ? mangle(field.value) : field.value
        field_names[field.value] = fname

        fname_id = make_ident(fname)
        ctor.params << fname_id
        slot = MemberExpression.new(this_id, fname_id, false)
        ass = AssignmentExpression.new(slot, fname_id)
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
                fname = field_names[field.value]
                type_scope[field.value] = "#{self_name}/#{fname}"
              end if fields

              # FIXME: oh god, no out-args please
              args_len_out = []
              fn = translate_deftype_method(limb, naked, args_len_out)
              args_len = args_len_out[0]

              self_decl = VariableDeclaration.new
              self_dtor = VariableDeclarator.new(make_ident(self_name), Identifier.new('this'))
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
            proto = ident(limb.value)
            protocol_name = MemberExpression.new(proto, ident("protocol-name"), false)
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
              invoke_apply = MemberExpression.new(ident("-invoke"), Identifier.new("apply"), false)
              arguments = Identifier.new('arguments')
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
      block.body << ReturnStatement.new(ident(name.value))

      ex = make_ident("exports/#{name}")
      dtor.init = AssignmentExpression.new(ex, dtor.init)
      decl.declarations << dtor

      @builder << decl
    end

    def translate_deftype_method(limb, naked, args_len_out)
      fn = nil
      matches = matches?(limb.inner.drop(1), FN_PATTERN)
      ser!("Invalid fn form in deftype: #{limb}", list) unless matches

      name, args, body = matches
      args_len_out << args.inner.length

      if naked
        t = limb.token
        do_vec = Hamster::Vector.new([AST::Symbol.new(t, "do")] + body)
        do_block = AST::List.new(t, do_vec)

        ser!("Function method needs at list one argument", t) if args.inner.empty?
        this_as_vec = Hamster.vector(AST::Symbol.new(t, "this-as"),
                                      args.inner.first,
                                      do_block)
        this_as = AST::List.new(t, this_as_vec)

        remaining_args = AST::Vector.new(t, args.inner.drop(1))
        fn = translate_fn_inner(remaining_args, [this_as], :name => (name ? name.value : nil))
      else
        fn = translate_fn_inner(args, body, :name => (name ? name.value : nil))
      end
      fn
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

    def translate_def(list)
      matches = matches?(list, DEF_PATTERN)
      ser!("Invalid def form", list) unless matches

      name, rest = matches
      init = nil

      case rest.length
      when 1
        init = as_expr(rest[0])
      when 2
        doc = rest[0]
        unless AST::String === doc
          ser!("Invalid def form", list)
        end
        init = as_expr(rest[1])
      else
        ser!("Invalid def form", list)
      end

      ex = make_ident("exports/#{name}")
      ass = AssignmentExpression.new(ex, init)
      @builder << make_decl(make_ident(name.value), ass)
    end

    DEFN_PATTERN       = ":sym :meta? :str? [:expr*] :expr*".freeze
    DEFN_MULTI_PATTERN = ":sym :meta? :str? :list+".freeze

    def translate_defn(list, export: true)
      f = nil
      _name = nil

      simple_matches = matches?(list, DEFN_PATTERN)
      if simple_matches
        name, meta, doc, args, body = simple_matches
        _name = name
        f = translate_fn_inner(args, body, :name => name.value)
      else
        multi_matches = matches?(list, DEFN_MULTI_PATTERN)
        if multi_matches
          name, meta, doc, variants = multi_matches
          _name = name
          f = translate_fn_inner_multi(variants, :name => name.value)
        else
          ser!("Invalid defn form", list)
        end
      end

      lhs = Identifier.new(mangle(_name.value))
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
      matches = matches?(list, FN_PATTERN)
      ser!("Invalid fn form: #{list.join(" ")}", list) unless matches

      name, args, body = matches
      fn = translate_fn_inner(args, body, :name => (name ? name.value : nil))
      @builder << fn
      nil
    end

    def variadic_args?(args)
      args.inner.any? { |x| x.sym?('&') }
    end

    def translate_variadic_fn_inner(args, body, name: nil)
      t = args.inner.first.token

      fixed_args    = args.inner.take_while { |x| !x.sym?('&') }
      variadic_args = args.inner.drop(fixed_args.length + 1)
      ser!("Internal error: Invalid variadic state", body) unless variadic_args.length == 1
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

      arg_vec <<= variadic_arg
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
                                  AST::Symbol.new(t, "js-arguments"))
      arglen = AST::List.new(t, arglen_vec)
      arg_comp_vec = Hamster.vector(gt_sym, arglen, num_fixed_args)
      arg_comp = AST::List.new(t, arg_comp_vec)

      rest_of_args_vec = Hamster.vector(AST::Symbol.new(t, "IndexedSeq."),
                                        AST::Symbol.new(t, "js-arguments"),
                                        num_fixed_args)
      rest_of_args = AST::List.new(t, rest_of_args_vec)

      if variadic_arg.map?
        # make a map out of them (last-pos keyword args)
        map_make_vec = Hamster.vector(AST::Symbol.new(t, "apply"),
                                      AST::Symbol.new(t, "hash-map"),
                                      rest_of_args)
        rest_of_args = AST::List.new(t, map_make_vec)
      end

      if_enough_args_vec = Hamster.vector(if_sym, arg_comp, rest_of_args, nil_sym)
      if_enough_args = AST::List.new(t, if_enough_args_vec)
      varargs_prepared = if_enough_args

      inner_sym = AST::Symbol.new(t, "inner")
      bindings_vec = Hamster.vector(inner_sym, inner_fn, variadic_sym, varargs_prepared)
      bindings = AST::Vector.new(t, bindings_vec)

      this_alias = AST::Symbol.new(t, fresh("this_as"))
      this_as_vec = Hamster.vector(AST::Symbol.new(t, "this-as"), this_alias)

      apply_sym = AST::Symbol.new(t, ".call")
      inner_call_vec = Hamster.vector(apply_sym, inner_sym, this_alias)
      arg_names.each do |name|
        inner_call_vec <<= AST::Symbol.new(t, name)
      end
      inner_call_vec <<= variadic_sym
      inner_call = AST::List.new(t, inner_call_vec)

      let_vec = Hamster.vector(let_sym, bindings, inner_call)
      let = AST::List.new(t, let_vec)
      this_as_vec <<= let

      outer_body = AST::List.new(t, this_as_vec)

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
          lhs = AST::Vector.new(t, args.inner)
          iseq      = AST::Symbol.new(t, "IndexedSeq.")
          arguments = AST::Symbol.new(t, "js-arguments")
          zero      = AST::Literal.new(t, 0)
          rhs = AST::List.new(t, Hamster.vector(iseq, arguments, zero))

          @builder.into(fn.body, :statement) do
            destructure(lhs, rhs)
          end
        else
          args.inner.each do |arg|
            @builder.declare(arg.value, arg.value)
            fn.params << make_ident(arg.value)
          end
        end

        recursive = body.any? { |x| contains_recur?(x) }
        if recursive
          t = body.first.token
          bindings = []
          scope = Scope.new

          args.inner.each do |arg|
            sym = AST::Symbol.new(t, arg.value)
            bindings << sym
            bindings << sym
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
      fn = FunctionExpression.new(nil)
      arity_cache = {}
      variadic_arity = -1

      max_arity = 0
      name_candidate = nil

      scope = Scope.new
      scope[name] = name if name

      @builder.with_scope(scope) do
        @builder.into(fn, :statement) do
          variants.each do |variant|
            matches = matches?(variant.inner, FN_PATTERN)
            ser!("Invalid function variant", variant) unless matches

            _, args, body = matches
            ifn = translate_fn_inner(args, body)

            arity = if args.inner.any? { |x| x.sym?('&') }
                      variadic_arity = 0
                      args.inner.each do |arg|
                        break if arg.sym?('&')
                        variadic_arity += 1
                      end
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
          end

          numargs = MemberExpression.new(Identifier.new('arguments'), Identifier.new('length'), false)
          sw = SwitchStatement.new(numargs)

          arg_names = []
          if name_candidate
            name_candidate.take_while { |x| !x.sym?('&') }.each do |x|
              arg_names << (x.sym? ? x.value : fresh('p'))
            end
          elsif max_arity > 0
            raise "No name candidate!"
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
              mexp = MemberExpression.new(make_ident(tmp), make_ident('apply'), false)
              call = CallExpression.new(mexp)
              call << Identifier.new('this')
              call << Identifier.new('arguments')
            else
              mexp = MemberExpression.new(make_ident(tmp), make_ident('call'), false)
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
      end

      return fn
    end

    def translate_chain(rest)
      curr = rest.first
      forms = rest.drop(1)

      until forms.empty?
        form = forms.first; forms = forms.drop(1)

        case form
        when AST::List
          dot = AST::Symbol.new(form.token, ".")
          curr = AST::List.new(form.token, form.inner.insert(1, curr).insert(0, dot))
        when AST::Symbol
          ser!("Expected access in chain") unless form.value.start_with?("-")
          dod = AST::Symbol.new(form.token, ".-")
          prop = AST::Symbol.new(form.token, form.value[1..-1])
          curr = AST::List.new(form.token, Hamster.vector(dod, prop, curr))
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
        index = 0
        body.each do |expr|
          if last_index == index
            @builder.vase.mode = :return
          end
          tr(expr)
          index += 1
        end
      end
    end

    def tr(expr)
      case expr
      when AST::Symbol
        if @quoting
          lit = make_literal(expr.value)
          @builder << CallExpression.new(ident("symbol"), [lit])
        else
          case expr.value
          when 'nil'
            @builder << make_literal(nil)
          when 'js-arguments'
            @builder << Identifier.new("arguments")
          else
            @builder << ident(expr.value)
          end
        end
        nil
      when AST::RegExp
        lit = make_literal(expr.value)
        if @quoting
          @builder << CallExpression.new(ident('--quoted-re'), [lit])
        else
          @builder << NewExpression.new(make_ident("js/RegExp"), [lit])
        end
        nil
      when AST::Literal
        @builder << make_literal(expr.value)
        nil
      when AST::Deref
        t = expr.token
        els = Hamster.vector(AST::Symbol.new(t, "deref"), expr.inner)
        tr(AST::List.new(t, els))
        nil
      when AST::Quote, Shin::AST::SyntaxQuote
        # TODO: find a less terrible solution.
        begin
          @quoting = true
          tr(expr.inner)
        ensure
          @quoting = false
        end
        nil
      when AST::Vector
        first = expr.inner.first
        if first && first.sym?('$')
          @builder.into!(ArrayExpression.new) do
            treach(expr.inner.drop(1))
          end
        else
          @builder.into!(CallExpression.new(ident('vector'))) do
            treach(expr.inner)
          end
        end
        nil
      when AST::Set
        @builder.into!(CallExpression.new(ident('hash-set'))) do
          treach(expr.inner)
        end
        nil
      when AST::Map
        first = expr.inner.first
        if first && first.sym?('$')
          list = expr.inner.drop(1)
          props = []
          list.each_slice(2) do |pair|
            key, val = pair
            k = if key.kw?
                  Literal.new(key.value)
                else
                  as_expr(key)
                end
            props << Property.new(k, as_expr(val))
          end
          @builder << ObjectExpression.new(props)
        else
          unless expr.inner.length.even?
            ser!("Map literal requires even number of forms", expr)
          end
          @builder.into!(CallExpression.new(ident('hash-map'))) do
            treach(expr.inner)
          end
        end
        nil
      when AST::Keyword
        lit = make_literal(expr.value)
        @builder << CallExpression.new(ident('keyword'), [lit])
        nil
      when AST::List
        if @quoting
          if expr.inner.empty?
            @builder << MemberExpression.new(ident("List"), Identifier.new("EMPTY"), false)
          else
            call = CallExpression.new(ident("list"))
            @builder.into(call, :expression) do
              treach(expr.inner)
            end
            @builder << call
          end
          nil
        else
          translate_listform(expr)
        end
      when AST::Unquote
        ser!("Invalid usage of unquoting outside of a quote: #{expr}", expr) unless @quoting
        call = CallExpression.new(ident('--unquote'))

        @builder.into(call, :expression) do
          spliced = false
          inner = expr.inner
          if AST::Deref === inner
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
      when AST::Closure
        ser!("Closures are supposed to be gone by the time we reach the translator", expr)
      else
        ser!("Unknown expr form #{expr} of type #{expr.class}", expr)
      end
    end

    def translate_listform(expr)
      list = expr.inner.to_a
      first = list.first

      unless first
        @builder << MemberExpression.new(ident("List"), Identifier.new("EMPTY"), false)
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

          property = make_ident(propname)
          object = as_expr(rest[0])
          @builder << MemberExpression.new(object, property, false)
        when name == '..'
          translate_chain(rest)
        when name =~ /^[.][A-Za-z_\-]*$/
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
          inst = NewExpression.new(ident(type_name))
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
        when "finally"
          # it's normalled all handled in translate_try
          ser!("Unexpected 'finally'", expr)
        when "cond"
          translate_cond(rest)
        when "condp"
          translate_condp(rest)
        when "loop"
          translate_loop(rest)
        when "this-as"
          translate_this_as(rest)
        when "recur"
          translate_recur(rest)
        when "set!"
          property, val = rest
          @builder << AssignmentExpression.new(as_expr(property), as_expr(val))
        when "declare-and-set!"
          property, val = rest
          @builder << make_decl(as_expr(property), as_expr(val))
        when "aset"
          translate_aset(rest)
        when "aget"
          translate_aget(rest)
        when "instance?"
          r, l = rest
          @builder << BinaryExpression.new('instanceof', as_expr(l), as_expr(r))
        when "throw"
          arg = rest.first or ser!("Throw what? Throw who? Throw how!", expr)
          @builder << ThrowStatement.new(as_expr(arg))
        when "*js-uop"
          op, arg = rest
          @builder << UnaryExpression.new(op.value, as_expr(arg))
        when "*js-bop"
          op, l, r = rest
          @builder << BinaryExpression.new(op.value, as_expr(l), as_expr(r))
        when "*js-call"
          fn = rest.first
          args = rest.drop(1)
          @builder.into!(CallExpression.new(as_expr(fn))) do
            treach(args)
          end
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
      mexp = MemberExpression.new(ifn, ident('call'), false)
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
      rhs = as_expr(rhs) if AST::Node === rhs

      case mode
      when :declare
        tmp = fresh("#{lhs.value}")
        @builder.declare(lhs.value, tmp)
        @builder << make_decl(tmp, rhs)
      when :assign
        @builder << AssignmentExpression.new(ident(lhs.value), rhs)
      else raise "Invalid mode: #{mode}"
      end
    end

    # Exploratory helpers

    def contains_recur?(ast)
      case ast
      when AST::List
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
      when AST::Sequence
        ast.inner.any? { |x| contains_recur?(x) }
      else
        false
      end
    end

    # JST helpers

    def make_decl(name, expr)
      expr = as_expr(expr)    if     AST::Node       === expr
      name = make_ident(name) unless Shin::JST::Identifier === name

      decl = VariableDeclaration.new
      dtor = VariableDeclarator.new(name, expr)
      decl.declarations << dtor
      decl
    end

    def make_literal(id)
      Literal.new(id)
    end

    def qualified?(name)
      name.include?("/") && name.size > 1
    end

    def make_ident(name)
      if qualified?(name)
        ns, member = name.split("/", 2)
        case ns
        when "js"
          # only case where identifiers aren't mangled.
          Identifier.new(member)
        else
          MemberExpression.new(Identifier.new(mangle(ns)),
                               Identifier.new(mangle(member)),
                               false)
        end
      else
        Identifier.new(mangle(name))
      end
    end

    def ident(name)
      if qualified?(name)
        make_ident(name)
      else
        if symbol = @builder.lookup(name)
          make_ident(symbol)
        else
          make_ident(name)
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
      token = token.token if AST::Node === token
      token = nil unless AST::Token === token

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
