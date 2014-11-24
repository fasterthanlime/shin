
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
  
  it "compiles a splicing vector-call macro" do
    expect(
      :source => %Q{ (vector-call [print "hello" "world"]) },
      :macros => %Q{
        (defmacro vector-call [v]
          `(~(first v) ~@(rest v)))
      }
    ).to have_output("hello world")
  end

  it "compiles a splicing when macro" do
    # when != if, because if has a if-cond-true-form and an
    # otherwise-form, but when only has if-cond-true forms
    expect(
      :source => %Q{
        (my-when [(> 3 1)
          (print "hello")
          (print "world")])
      },
      :macros => %Q{
        (defmacro my-when [args]
          (let [cond (first args)
                body (rest args)]
            `(if ~cond (do ~@body))))
      }
    ).to have_output("hello world")
  end

  it "compiles a recursive repeat macroe" do
    expect(
      :source => %Q{
        (my-repeat 3 (print "knock"))
      },
      :macros => %Q{
        (defmacro my-repeat [count body]
          (if (> count 0)
            `(do ~body ~(my-repeat (- count 1) body))))
      }
    ).to have_output("knock knock knock")
  end

  it "compiles a constructive repeat macro" do
    expect(
      :source => %Q{
        (my-repeat 3 (print "knock"))
      },
      :macros => %Q{
        (defmacro my-repeat [count body]
          (let [inner (fn rec [count body]
                         (if (> count 0)
                             (cons body (rec (- count 1) body))
                             '()))]
            `(do ~@(inner count body))))
      }
    ).to have_output("knock knock knock")
  end

end

