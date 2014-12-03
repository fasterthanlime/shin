
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

  it "list, bool -> list" do
    expect(
      :source => %Q{ (fast-mutator-test false (print "Works") (print "Oh-noes")) },
      :macros => %Q{
        (defmacro fast-mutator-test [cond if-false if-true]
          `(if (not ~cond) ~if-false ~if-true))
      }
    ).to have_output("Works")
  end

  it "list -> list" do
    expect(
      :source => %Q{ (fast-mutator-test ("Works" "well")) },
      :macros => %Q{
        (defmacro fast-mutator-test [form]
          (cons 'print form))
      }
    ).to have_output("Works well")
  end

  it "gets AST back from a macro" do
    expect(
      :source => %Q{ (fast-mutator-test) },
      :macros => %Q{ (defmacro fast-mutator-test [] `(print "IAMA macro")) }
    ).to have_output("IAMA macro")
  end

  it "passes AST back into a macro" do
    expect(
      :source => %Q{ (print (fast-mutator-test fruity-loops)) },
      :macros => %Q{ (defmacro fast-mutator-test [s] (-name s)) }
    ).to have_output("fruity-loops")
  end

  it "compiles a basic inverted-call macro" do
    expect(
      :source => %Q{ (fast-mutator-test print "world" "hello") },
      :macros => %Q{ (defmacro fast-mutator-test [f a b] `(~f ~b ~a)) }
    ).to have_output("hello world")
  end

  it "compiles a basic vector-call macro" do
    expect(
      :source => %Q{ (fast-mutator-test [print "hello" "world"]) },
      :macros => %Q{
        (defmacro fast-mutator-test [v]
          `(apply ~(first v) ~(vec (rest v))))
      }
    ).to have_output("hello world")
  end
  
  it "compiles a splicing vector-call macro" do
    expect(
      :source => %Q{ (fast-mutator-test [print "hello" "world"]) },
      :macros => %Q{
        (defmacro fast-mutator-test [v]
          `(~(first v) ~@(rest v)))
      }
    ).to have_output("hello world")
  end

  it "compiles a recursive repeat macroe" do
    expect(
      :source => %Q{
        (fast-mutator-test 3 (print "knock"))
      },
      :macros => %Q{
        (defmacro fast-mutator-test [count body]
          (if (> count 0)
            `(do ~body ~(fast-mutator-test (- count 1) body))))
      }
    ).to have_output("knock knock knock")
  end

  it "compiles a constructive repeat macro" do
    expect(
      :source => %Q{
        (fast-mutator-test 3 (print "knock"))
      },
      :macros => %Q{
        (defmacro fast-mutator-test [count body]
          (let [inner (fn rec [count body]
                         (if (> count 0)
                             (cons body (rec (- count 1) body))
                             '()))]
            `(do ~@(inner count body))))
      }
    ).to have_output("knock knock knock")
  end
end

