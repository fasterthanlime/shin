
RSpec.describe "Language", "basic macros" do
  it "gets AST back from a macro" do
    expect(
      :source => %Q{ (foobar) },
      :macros => %Q{ (defmacro foobar [] `(print "IAMA macro")) }
    ).to have_output("IAMA macro")
  end
end

