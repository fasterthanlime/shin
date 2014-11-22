
RSpec.describe "Language", "gensym" do
  it "manual gensym calls works" do
    expect(
      :source => %q{ (print (foobar "|" "1" "2")) },
      :macros => %q{
        (defmacro foobar [a b c]
         (let [sym (gensym)]
           `(let [~sym (str "<" ~a ">")]
              (str ~sym ~b ~sym ~c))))
      }
    ).to have_output("<|>1<|>2")
  end
end
