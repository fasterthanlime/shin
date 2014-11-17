
RSpec.describe "Language", "assoc" do
  it "works on maps (single kv)" do
    expect(%Q{ (print (= {:a "Hello" :b 1} (assoc {:b 1} :a "Hello"))) }).to have_output("true")
  end

  it "works on maps (replace)" do
    expect(%Q{ (print (= {:a "Hello" :b 1} (assoc {:a "Bye" :b 1} :a "Hello"))) }).to have_output("true")
  end

  it "works on maps (multi kv)" do
    expect(%Q{ (print (= {:a "Hello" :b "Farewell" :c 1} (assoc {:c 1} :a "Hello" :b "Farewell"))) }).to have_output("true")
  end

  it "works on vectors (single kv)" do
    expect(%Q{ (print (= ["Hello" "Earth"] (assoc ["Bye" "Earth"] 0 "Hello"))) }).to have_output("true")
  end

  it "works on vectors (multi kv)" do
    expect(%Q{ (print (= ["Hello" "Sir" "Lewis"] (assoc ["Sup" "Mate" "Lewis"] 0 "Hello" 1 "Sir"))) }).to have_output("true")
  end
end

