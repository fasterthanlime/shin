
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
end

