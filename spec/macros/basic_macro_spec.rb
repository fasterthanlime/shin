
RSpec.describe "Language", "basic macros" do
  it "gets AST back from a macro" do
    expect(
      :source => %Q{ (foobar) },
      :macros => %Q{ (defmacro foobar [] `(prn "IAMA macro")) }
    ).to have_output()
  end
end

