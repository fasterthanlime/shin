
# The trick to a successful feature is to give it a catchy name!
# AST roleplay is Shin::AST::* classes pretending to be ClojureScript
# data structures so that they can be manipulated by macros.
RSpec.describe "Infrastructure", "AST roleplay" do
  include Shin

  before(:all) do
    compiler = Shin::Compiler.new({})
    core_path = compiler.find_module("cljs.core")
    compiler.compile(File.read(core_path))

    @ctx = Shin::JsContext.new
    @ctx.providers << compiler
    @ctx.load("cljs.core")
  end

  describe "AST::List" do
    it "can call first" do
      s = js_call %Q{
        return core.first(input);
      }, :input => sample_list
      expect(s).to be_a(Shin::AST::Symbol)
    end
  end

  private

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

  def sample_list
    inner = Hamster.vector(sym("lloyd"), sym("franken"), sym("algae"))
    Shin::AST::List.new(sample_token, inner)
  end

end



