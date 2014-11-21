
RSpec.describe "Language", "dissoc" do
  it "works on maps (no k)" do
    expect(%Q{ (print (= {:a 1 :b 2} (dissoc {:a 1 :b 2}))) }).to have_output("true")
  end

  it "works on maps (single k)" do
    expect(%Q{ (print (= {:b 2} (dissoc {:a 1 :b 2} :a))) }).to have_output("true")
  end

  it "works on maps (multi k)" do
    expect(%Q{ (print (= {} (dissoc {:a 1 :b 2 :c 3} :a :b :c))) }).to have_output("true")
  end
end


