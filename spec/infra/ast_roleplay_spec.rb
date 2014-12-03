
# The trick to a successful feature is to give it a catchy name!
# AST roleplay is Shin::AST::* classes pretending to be ClojureScript
# data structures so that they can be manipulated by macros.
RSpec.describe "Infrastructure", "AST roleplay" do
  include Shin
  include Shin::Utils::Mangler
  include Shin::Utils::AstMaker

  before(:all) do
    compiler = Shin::Compiler.new({})
    core_path = compiler.find_module("cljs.core")
    compiler.compile(File.read(core_path))

    @ctx = Shin::JsContext.new
    @ctx.providers << compiler
    @ctx.load("cljs.core")
  end

  #####################################
  # Keyword specs
  #####################################

  describe "AST::Keyword" do
    describe "IKeyword" do
      it "satisfies IKeyword" do
        expect_satisfies?(:IKeyword, sample_kw).to be_truthy
      end

      it "truthful by keyword?" do
        expect_pred?(:keyword?, sample_kw).to be_truthy
      end
    end

    describe "INamed" do
      it "satisfies INamed" do
        expect_satisfies?(:INamed, sample_kw).to be_truthy
      end

      it "can call name" do
        k = sample_kw
        s = js_call %Q{
          return core.name(k);
        }, :k => k
        expect(s).to eq(k.value)
      end
    end

    describe "IPrintable" do
      it "satisfies IPrintable" do
        expect_satisfies?(:IPrintable, sample_kw).to be_truthy
      end

      it "can call pr-str" do
        k = sample_kw
        s = js_call %Q{
          return core.pr$_str(k);
        }, :k => k
        expect(s).to eq(k.to_s)
      end
    end

    describe "IEquiv" do
      it "satisfies IEquiv" do
        expect_satisfies?(:IEquiv, sample_kw).to be_truthy
      end

      describe "can be compared with keyword" do
        it "as lhs" do
          lhs = sample_kw

          expect(js_call(%Q{
            var rhs = core.keyword("#{lhs.value}");
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_truthy

          expect(js_call(%Q{
            var rhs = core.keyword("definitely-not-equal");
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey

          expect(js_call(%Q{
            var rhs = "not even a keyword";
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
        end

        it "as rhs" do
          rhs = sample_kw

          expect(js_call(%Q{
            var lhs = core.keyword("#{rhs.value}");
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_truthy

          expect(js_call(%Q{
            var lhs = core.keyword("definitely-not-equal");
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey

          expect(js_call(%Q{
            var lhs = "not even a keyword";
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
        end
      end
    end

    describe "IFn" do
      it "satisfies IFn" do
        expect_satisfies?(:IFn, sample_kw).to be_truthy
      end

      it "is callable" do
        k = sample_kw
        s = js_call %Q{
          var v = core.hash$_map(core.keyword("#{k.value}"), "yellow");
          return k.call(null, v);
        }, :k => k
        expect(s).to eq("yellow")
      end

      it "is callable (with not-found)" do
        k = sample_kw

        expect(js_call(%Q{
          var v = core.hash$_map(core.keyword("#{k.value}"), "yellow");
          return k.call(null, v);
        }, :k => k)).to eq("yellow")
        expect(js_call(%Q{
          var v = core.hash$_map();
          return k.call(null, v, "submarine");
        }, :k => k)).to eq("submarine")
      end
    end
  end

  #####################################
  # Symbol specs
  #####################################

  describe "AST::Symbol" do
    describe "ISymbol" do
      it "satisfies ISymbol" do
        expect_satisfies?(:ISymbol, sample_sym).to be_truthy
      end

      it "truthful by symbol?" do
        expect_pred?(:symbol?, sample_sym).to be_truthy
      end
    end

    describe "INamed" do
      it "satisfies INamed" do
        expect_satisfies?(:INamed, sample_sym).to be_truthy
      end

      it "can call name" do
        k = sample_sym
        s = js_call %Q{
          return core.name(k);
        }, :k => k
        expect(s).to eq(k.value)
      end
    end

    describe "IPrintable" do
      it "satisfies IPrintable" do
        expect_satisfies?(:IPrintable, sample_sym).to be_truthy
      end

      it "can call pr-str" do
        k = sample_sym
        s = js_call %Q{
          return core.pr$_str(k);
        }, :k => k
        expect(s).to eq(k.to_s)
      end
    end

    describe "IEquiv" do
      it "satisfies IEquiv" do
        expect_satisfies?(:IEquiv, sample_sym).to be_truthy
      end

      describe "can be compared with symbol" do
        it "as lhs" do
          lhs = sample_sym

          expect(js_call(%Q{
            var rhs = core.symbol("#{lhs.value}");
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_truthy

          expect(js_call(%Q{
            var rhs = core.symbol("definitely-not-equal");
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey

          expect(js_call(%Q{
            var rhs = "not even a symbol";
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
        end

        it "as rhs" do
          rhs = sample_sym

          expect(js_call(%Q{
            var lhs = core.symbol("#{rhs.value}");
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_truthy

          expect(js_call(%Q{
            var lhs = core.symbol("definitely-not-equal");
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey

          expect(js_call(%Q{
            var lhs = "not even a symbol";
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
        end
      end
    end

    describe "IFn" do
      it "satisfies IFn" do
        expect_satisfies?(:IFn, sample_sym).to be_truthy
      end

      it "is callable" do
        k = sample_sym
        s = js_call %Q{
          var v = core.hash$_map(core.symbol("#{k.value}"), "yellow");
          return k.call(null, v);
        }, :k => k
        expect(s).to eq("yellow")
      end

      it "is callable (with not-found)" do
        k = sample_sym

        expect(js_call(%Q{
          var v = core.hash$_map(core.symbol("#{k.value}"), "yellow");
          return k.call(null, v);
        }, :k => k)).to eq("yellow")
        expect(js_call(%Q{
          var v = core.hash$_map();
          return k.call(null, v, "submarine");
        }, :k => k)).to eq("submarine")
      end
    end
  end

  #####################################
  # List specs
  #####################################

  describe "AST::List" do
    describe "IList" do
      it "satisfies IList" do
        expect_satisfies?(:IList, sample_list).to be_truthy
      end

      it "truthful by list?" do
        expect_pred?(:list?, sample_list).to be_truthy
      end
    end

    describe "ISeq" do
      it "satisfies ISeq" do
        expect_satisfies?(:ISeq, sample_list).to be_truthy
      end

      it "satisfies ASeq" do
        expect_satisfies?(:ASeq, sample_list).to be_truthy
      end

      it "can call first" do
        l = sample_list
        s = js_call %Q{
          return core.first(l);
        }, :l => l
        expect(s).to be(l.inner.first)
      end

      it "can call first (unwrap)" do
        s = js_call %Q{
          return core.first(l) + 41;
        }, :l => numeric_list
        expect(s).to eq(42)
      end

      it "can call rest" do
        s = js_call %Q{
          return core.rest(l);
        }, :l => sample_list
        expect(s).to be_a(Shin::AST::List)
        expect(s.inner.count).to eq(2)
      end
    end

    describe "INext" do
      it "satisfies INext" do
        expect_satisfies?(:INext, sample_list).to be_truthy
      end

      it "can call next" do
        s = js_call %Q{
          return core.next(l);
        }, :l => sample_list
        expect(s).to be_a(Shin::AST::List)
        expect(s.inner.count).to eq(2)
      end

      it "next returns nil eventually" do
        s = js_call %Q{
          var res = l;
          while (res) { res = core.next(res); }
          return res;
        }, :l => sample_list
        expect(s).to be_nil
      end
    end

    describe "ICounted" do
      it "satisfies ICounted" do
        expect_satisfies?(:ICounted, sample_list).to be_truthy
      end

      it "can call count" do
        s = js_call %Q{
          return core.count(l);
        }, :l => sample_list
        expect(s).to eq(3)
      end
    end

    describe "IStack" do
      it "satisfies IStack" do
        expect_satisfies?(:IStack, sample_list).to be_truthy
      end

      it "can call peek" do
        l = sample_list
        s = js_call %Q{
          return core.peek(l);
        }, :l => l
        expect(s).to be(l.inner.first)
      end

      it "can call peek (unwrap)" do
        s = js_call %Q{
          return core.peek(l) + 41;
        }, :l => numeric_list
        expect(s).to eq(42)
      end

      it "can call pop" do
        s = js_call %Q{
          return core.pop(l);
        }, :l => sample_list
        expect(s).to be_a(Shin::AST::List)
        expect(s.inner.count).to eq(2)
      end

      it "pops from the front" do
        l = sample_list
        s = js_call %Q{
          return core.first(core.pop(core.pop(l)));
        }, :l => l
        expect(s).to eq(l.inner.last)
      end
    end

    describe "ICollection" do
      it "satisfies ICollection" do
        expect_satisfies?(:ICollection, sample_list).to be_truthy
      end

      it "can call conj" do
        l = sample_list
        s = js_call %Q{
          return core.conj(l, 42);
        }, :l => l
        expect(s).to be_a(Shin::AST::List)
        first = s.inner.first
        expect(first).to be_a(Shin::AST::Literal)
        expect(first.value).to eq(42)
      end
    end

    describe "ISequential" do
      it "satisfies ISequential" do
        expect_satisfies?(:ISequential, sample_list).to be_truthy
      end
    end

    describe "IEquiv" do
      it "satisfies IEquiv" do
        expect_satisfies?(:IEquiv, sample_list).to be_truthy
      end

      describe "can be compared with a list" do
        it "as lhs" do
          lhs = numeric_list

          expect(js_call(%Q{
            var rhs = core.list(1, 2, 3, 4, 5, 6);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_truthy
          expect(js_call(%Q{
            var rhs = core.list(1, 2, 3);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
          expect(js_call(%Q{
            var rhs = core.list(1, 2, 3, 4, 4, 6);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
          expect(js_call(%Q{
            var rhs = core.list(1, 2, 3, 4, 5, 6, 7);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
        end

        it "as rhs" do
          rhs = numeric_list

          expect(js_call(%Q{
            var lhs = core.list(1, 2, 3, 4, 5, 6);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_truthy
          expect(js_call(%Q{
            var lhs = core.list(1, 2, 3);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
          expect(js_call(%Q{
            var lhs = core.list(1, 2, 3, 4, 4, 6);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
          expect(js_call(%Q{
            var lhs = core.list(1, 2, 3, 4, 5, 6, 7);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
        end
      end
    end

    describe "IReduce" do
      it "satisfies IReduce" do
        expect_satisfies?(:IReduce, sample_list).to be_truthy
      end

      it "reduces without an initial value" do
        s = js_call %Q{
          return core.reduce(core.#{mangle('+')}, l);
        }, :l => numeric_list
        expect(s).to eq(21)
      end

      it "reduces with an initial value" do
        s = js_call %Q{
          return core.reduce(core.#{mangle('+')}, 21, l);
        }, :l => numeric_list
        expect(s).to eq(42)
      end
    end

    describe "IPrintable" do
      it "satisfies IPrintable" do
        expect_satisfies?(:IPrintable, sample_list).to be_truthy
      end

      it "has a working pr-str (symbols)" do
        s = js_call %Q{
           return core.pr$_str(l);
        }, :l => sample_list
        expect(s).to eq("(lloyd franken algae)")
      end

      it "has a working pr-str (numbers)" do
        s = js_call %Q{
           return core.pr$_str(l);
        }, :l => numeric_list
        expect(s).to eq("(1 2 3 4 5 6)")
      end
    end
  end

  #####################################
  # Vector specs
  #####################################

  describe "AST::Vector" do
    describe "IVector" do
      it "satisfies IVector" do
        expect_satisfies?(:IVector, sample_vec).to be_truthy
      end

      it "truthful by vector?" do
        expect_pred?(:vector?, sample_vec).to be_truthy
      end
    end

    describe "ISeq" do
      it "satisfies ISeq" do
        expect_satisfies?(:ISeq, sample_vec).to be_truthy
      end

      it "satisfies ASeq" do
        expect_satisfies?(:ASeq, sample_vec).to be_truthy
      end

      it "can call first" do
        l = sample_vec
        s = js_call %Q{
          return core.first(l);
        }, :l => l
        expect(s).to be(l.inner.first)
      end

      it "can call first (unwrap)" do
        s = js_call %Q{
          return core.first(l) + 36;
        }, :l => numeric_vec
        expect(s).to eq(42)
      end

      it "can call rest" do
        s = js_call %Q{
          return core.rest(l);
        }, :l => sample_vec
        expect(s).to be_a(Shin::AST::Vector)
        expect(s.inner.count).to eq(2)
      end
    end

    describe "INext" do
      it "satisfies INext" do
        expect_satisfies?(:INext, sample_vec).to be_truthy
      end

      it "can call next" do
        s = js_call %Q{
          return core.next(l);
        }, :l => sample_vec
        expect(s).to be_a(Shin::AST::Vector)
        expect(s.inner.count).to eq(2)
      end

      it "next returns nil eventually" do
        s = js_call %Q{
          var res = l;
          while (res) { res = core.next(res); }
          return res;
        }, :l => sample_vec
        expect(s).to be_nil
      end
    end

    describe "ICounted" do
      it "satisfies ICounted" do
        expect_satisfies?(:ICounted, sample_vec).to be_truthy
      end

      it "can call count" do
        s = js_call %Q{
          return core.count(l);
        }, :l => sample_vec
        expect(s).to eq(3)
      end
    end

    describe "IStack" do
      it "satisfies IStack" do
        expect_satisfies?(:IStack, sample_vec).to be_truthy
      end

      it "can call peek" do
        l = sample_vec
        s = js_call %Q{
          return core.peek(l);
        }, :l => l
        expect(s).to be(l.inner.first)
      end

      it "can call peek (unwrap)" do
        s = js_call %Q{
          return core.peek(l) + 36;
        }, :l => numeric_vec
        expect(s).to eq(42)
      end

      it "can call pop" do
        s = js_call %Q{
          return core.pop(l);
        }, :l => sample_vec
        expect(s).to be_a(Shin::AST::Vector)
        expect(s.inner.count).to eq(2)
      end

      it "pops from the front" do
        l = sample_vec
        s = js_call %Q{
          return core.first(core.pop(core.pop(l)));
        }, :l => l
        expect(s).to eq(l.inner.last)
      end
    end

    describe "ICollection" do
      it "satisfies ICollection" do
        expect_satisfies?(:ICollection, sample_vec).to be_truthy
      end

      it "can call conj" do
        l = sample_vec
        s = js_call %Q{
          return core.conj(l, 42);
        }, :l => l
        expect(s).to be_a(Shin::AST::Vector)
        last = s.inner.last
        expect(last).to be_a(Shin::AST::Literal)
        expect(last.value).to eq(42)
      end
    end

    describe "ISequential" do
      it "satisfies ISequential" do
        expect_satisfies?(:ISequential, sample_vec).to be_truthy
      end
    end

    describe "IEquiv" do
      it "satisfies IEquiv" do
        expect_satisfies?(:IEquiv, sample_vec).to be_truthy
      end

      describe "can be compared with a vector" do
        it "as lhs" do
          lhs = numeric_vec

          expect(js_call(%Q{
            var rhs = core.vector(6, 5, 4, 3, 2, 1);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_truthy
          expect(js_call(%Q{
            var rhs = core.vector(6, 5, 4);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
          expect(js_call(%Q{
            var rhs = core.vector(6, 5, 4, 4, 2, 1);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
          expect(js_call(%Q{
            var rhs = core.vector(6, 5, 4, 3, 2, 1, 0);
            return core.#{mangle('=')}(lhs, rhs);
          }, :lhs => lhs)).to be_falsey
        end

        it "as rhs" do
          rhs = numeric_vec

          expect(js_call(%Q{
            var lhs = core.vector(6, 5, 4, 3, 2, 1);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_truthy
          expect(js_call(%Q{
            var lhs = core.vector(6, 5, 4);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
          expect(js_call(%Q{
            var lhs = core.vector(6, 5, 4, 4, 2, 1);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
          expect(js_call(%Q{
            var lhs = core.vector(6, 5, 4, 3, 2, 1, 0);
            return core.#{mangle('=')}(lhs, rhs);
          }, :rhs => rhs)).to be_falsey
        end
      end
    end

    describe "IReduce" do
      it "satisfies IReduce" do
        expect_satisfies?(:IReduce, sample_vec).to be_truthy
      end

      it "reduces without an initial value" do
        s = js_call %Q{
          return core.reduce(core.#{mangle('+')}, l);
        }, :l => numeric_vec
        expect(s).to eq(21)
      end

      it "reduces with an initial value" do
        s = js_call %Q{
          return core.reduce(core.#{mangle('+')}, 21, l);
        }, :l => numeric_vec
        expect(s).to eq(42)
      end
    end

    describe "IPrintable" do
      it "satisfies IPrintable" do
        expect_satisfies?(:IPrintable, sample_vec).to be_truthy
      end

      it "has a working pr-str (symbols)" do
        s = js_call %Q{
           return core.pr$_str(l);
        }, :l => sample_vec
        expect(s).to eq("[:these :arent :spartae]")
      end

      it "has a working pr-str (numbers)" do
        s = js_call %Q{
           return core.pr$_str(l);
        }, :l => numeric_vec
        expect(s).to eq("[6 5 4 3 2 1]")
      end
    end

    # TODO: specs for IIndexed
    # TODO: specs for ILookup
    # TODO: specs for IVector
    # TODO: specs for IAssociative
    # TODO: specs for IKVReduce
    # TODO: specs for IFn
  end

  #####################################
  # Map specs
  #####################################

  describe "AST::Map" do
    describe "IAssociative" do
      it "satisfies IAssociative" do
        expect_satisfies?(:IAssociative, empty_map).to be_truthy
      end

      it "can call assoc" do
        m = empty_map
        s = js_call %Q{
          var k = "hymnos";
          var v = "domine";
          return core.assoc(m, k, v);
        }, :m => m
        expect(s.inner.length).to eq(2)
        expect(s.inner[0]).to eql(literal("hymnos"))
        expect(s.inner[1]).to eql(literal("domine"))
      end
    end

    describe "ILookup" do
      it "satisfies ILookup" do
        expect_satisfies?(:ILookup, empty_map).to be_truthy
      end

      it "can call get" do
        m = sample_map
        s = js_call %Q{
          var k = core.keyword("a");
          return core.get(m, k);
        }, :m => m
        expect(s).to eql(kw("A"))
      end
    end
  end

  private

  def expect_pred?(pred, val)
    s = js_call %Q{
      return core.#{mangle(pred.to_s)}(val);
    }, :val => val
    expect(s)
  end

  def expect_satisfies?(protocol, val)
    s = js_call %Q{
      return core.satisfies$q(core.#{protocol}, val);
    }, :val => val
    expect(s)
  end

  def js_call(body, args)
    unless body.include?("return")
      raise "Called js_call without a return - won't eval to anything"
    end

    f = @ctx.eval %Q{
      (function(#{args.keys.join(', ')}) {
        #{alias_core}
        #{body}
      })
    }
    f.call(*args.values)
  end

  def alias_core
    %Q{
      var core = $kir.modules["cljs.core"].exports;
    }
  end

end



