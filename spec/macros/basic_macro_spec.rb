
RSpec.describe "Language", "basic macros" do
  it "gets AST back from a macro" do
    expect(
      :source => %Q{ (foobar) },
      :macros => %Q{ (defmacro foobar [] `(print "IAMA macro")) }
    ).to have_output("IAMA macro")
  end

  it "passes AST into a macro" do
    expect(
      :source => %Q{ (print (my-name fruity-loops)) },
      :macros => %Q{ (defmacro my-name [s] (.-_name s)) }
    ).to have_output("fruity-loops")
  end

  it "compiles a basic inverted-call macro" do
    expect(
      :source => %Q{ (inverted-call print "world" "hello") },
      :macros => %Q{ (defmacro inverted-call [f a b] `(~f ~b ~a)) }
    ).to have_output("hello world")
  end

  it "compiles a basic vector-call macro" do
    expect(
      :source => %Q{ (vector-call [print "hello" "world"]) },
      :macros => %Q{
        (defmacro vector-call [v]
          `(apply ~(first v) ~(rest v)))
      }
    ).to have_output("hello world")
  end
end

