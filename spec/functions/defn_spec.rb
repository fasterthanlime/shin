
RSpec.describe "Language", "defn" do
  it "defines and calls a simple function" do
    expect(%Q{ (defn hello [] (print "Hello")) (hello) }).to have_output("Hello")
  end

  it "accepts various valid defn forms" do
    expect(%Q{(defn hello [] "Hello") (print (hello))}).to have_output("Hello")
    expect(%Q{(defn hello "Greets someone" [] "Hello") (print (hello))}).to have_output("Hello")
    expect(%Q{(defn hello [] "Garbage" "Hello") (print (hello))}).to have_output("Hello")
    expect(%Q{(defn hello "Greets someone" [] "Garbage" "Hello") (print (hello))}).to have_output("Hello")
  end

  it "raises on invalid defn forms" do
    expect { expect(%Q{(defn)}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(defn name)}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(defn name "Doc here." woops [])}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(defn name woops [] expr)}).to have_output("") }.to raise_error(Shin::SyntaxError)
  end

  it "handles a simple argument list" do
    expect(%Q{(defn foo [a] (print a)) (foo "Dolly")}).to have_output("Dolly")
    expect(%Q{(defn foo [a b] (print (+ a b))) (foo 5 10) (foo 20 10)}).to have_output("15 30")
  end
end

