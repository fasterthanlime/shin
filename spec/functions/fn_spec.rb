
RSpec.describe "Language", "fn" do
  it "defines and calls a simple anonymous function" do
    expect(%Q{ ((fn [] (print "Hello"))) }).to have_output("Hello")
  end

  it "defines and calls a simple named function" do
    expect(%Q{ ((fn hello [] (print "Hello"))) }).to have_output("Hello")
  end

  it "defines and calls a simple anonymous function (with return value)" do
    expect(%Q{ (print ((fn [] (str "Hel" "lo")))) }).to have_output("Hello")
  end

  it "has def and fn working in conjunction" do
    expect(%Q{ (def hello (fn [] (print "Hello"))) (hello) }).to have_output("Hello")
  end

  it "supports anonymous functions as arguments" do
    expect(%Q{
           (defn swap-call [f a b] (f b a))
           (swap-call (fn [a b] (print a b)) "world" "Hello")
           }).to have_output("Hello world")
  end

  it "defines a recursive function" do
    expect(%Q{
           (print
            ((fn rec [x]
              (if (< x 10)
                  (rec (inc x))
                  x))
            0))
           }).to have_output("10")
  end

  describe "multiple arity" do
    it "calls the correct arity" do
      expect(%Q{
            (defn f
              ([x]          "1")
              ([x y]        "2")
              ([x y & more] "variadic"))
            (print (f nil))
            (print (f nil nil))
            (print (f nil nil nil))
            }).to have_output("1 2 variadic")
    end

    it "errs on fixed arity > variadic arity" do
      expect do
        expect(%Q{
              (defn f
                ([x y z]          "1")
                ([& more] "variadic"))
              }).to have_output("")
      end.to raise_error(Shin::SyntaxError)
    end

    it "errs on wrong arity call" do
      expect do
        expect(%Q{
              (defn f
                ([x y z] "1"))
              (f nil)
              }).to have_output("")
      end.to raise_error(V8::Error)
    end
  end
end

