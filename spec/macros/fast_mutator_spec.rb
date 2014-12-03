
RSpec.describe "Language", "fast mutator" do
  it "string -> string" do
    expect(
      :source => %Q{ (print (fast-mutator-test "hello" " dolly")) },
      :macros => %Q{ (defmacro fast-mutator-test [a b] (str a b)) }
    ).to have_output("hello dolly")
  end

  it "string -> list" do
    expect(
      :source => %Q{ (fast-mutator-test "hello" "dolly") },
      :macros => %Q{ (defmacro fast-mutator-test [a b] `(print ~a ~b)) }
    ).to have_output("hello dolly")
  end
end

