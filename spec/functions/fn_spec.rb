
RSpec.describe "Language", "fn" do
  it "defines and calls a simple anonymous function" do
    expect(%Q{ ((fn [] (print "Hello"))) }).to have_output("Hello")
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
end

