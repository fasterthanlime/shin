
# The trick to a successful feature is to give it a catchy name!
# AST roleplay is Shin::AST::* classes pretending to be ClojureScript
# data structures so that they can be manipulated by macros.
RSpec.describe "Infrastructure", "AST roleplay" do
  include Shin
  include Shin::Utils::Mangler

  before(:all) do
    compiler = Shin::Compiler.new({})
    core_path = compiler.find_module("cljs.core")
    compiler.compile(File.read(core_path))

    @ctx = Shin::JsContext.new
    @ctx.providers << compiler
    @ctx.load("cljs.core")
  end

  describe "AST::Keyword" do
    describe "IKeyword" do
      it "satisfies IKeyword" do
        expect_satisfies?(:IKeyword, sample_kw).to be_truthy
      end

      it "truthful by keyword?" do
        expect_pred?(:keyword?, sample_kw).to be_truthy
      end
    end
  end

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
        expect(s).to eq(l.inner.first)
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

  def sample_token
    Shin::AST::Token.new("dummy", 42)
  end

  def sym(name)
    Shin::AST::Symbol.new(sample_token, name)
  end

  def kw(name)
    Shin::AST::Keyword.new(sample_token, name)
  end

  def literal(value)
    Shin::AST::Literal.new(sample_token, value)
  end

  def sample_kw
    kw("neverland")
  end

  def sample_list
    inner = Hamster.vector(sym("lloyd"), sym("franken"), sym("algae"))
    Shin::AST::List.new(sample_token, inner)
  end

  def numeric_list
    inner = Hamster.vector()
    (1..6).each do |n|
      inner <<= Shin::AST::Literal.new(sample_token, n)
    end
    Shin::AST::List.new(sample_token, inner)
  end

end



