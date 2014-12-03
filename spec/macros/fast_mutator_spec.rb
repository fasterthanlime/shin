
RSpec.describe "Language", "fast mutator" do
  it "tests the fast mutator" do
    expect(
      :source => %Q{ (print (fast-mutator-test "hello" " dolly")) },
      :macros => %Q{ (defmacro fast-mutator-test [a b] `(str a b)) }
    ).to have_output("hello dolly")
  end
end

