
RSpec.describe "Language", "gensym" do
  it "works when called explicitly" do
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

  it "works when used via reader macro (simple)" do
    expect(
      :source => %q{ (print (foobar "|" "1" "2")) },
      :macros => %q{
        (defmacro foobar [a b c]
          `(let [d# (str "<" ~a ">")]
            (str d# ~b d# ~c)))
      }
    ).to have_output("<|>1<|>2")
  end

  it "works when used via reader macro (multiple)" do
    expect(
      :source => %q{ (print (foobar "|" "1" "2")) },
      :macros => %q{
        (defmacro foobar [a b c]
          `(let [l# (str "<")
                 r# (str ">")
                 f# (str l# ~a r#)]
            (str f# ~b f# ~c)))
      }
    ).to have_output("<|>1<|>2")
  end
end
