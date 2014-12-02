
RSpec.describe "Language" do
  describe "assoc" do
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

  describe "assoc-in" do
    it "works (replace)" do
      expect(%Q{
             (print (= {:a {:b {:c "Crystal"}}} (assoc-in {:a {:b {:c "Nugget"}}} [:a :b :c] "Crystal")))
             }).to have_output("true")
    end 

    it "works (create levels)" do
      expect(%Q{
             (print (= {:a {:b {:c "Crystal"}}} (assoc-in {} [:a :b :c] "Crystal")))
             }).to have_output("true")
    end 
  end

  describe "update-in" do
    it "works (0 args)" do
      expect(%Q{
             (print (= {:a {:b {:c 42}}} (update-in {:a {:b {:c 41}}} [:a :b :c] inc)))
             }).to have_output("true")
    end 

    it "works (1 arg)" do
      expect(%Q{
             (print (= {:a {:b {:c 42}}} (update-in {:a {:b {:c 21}}} [:a :b :c] * 2)))
             }).to have_output("true")
    end 

    it "works (2 args)" do
      expect(%Q{
             (print (= {:a {:b {:c 42}}} (update-in {:a {:b {:c 2}}} [:a :b :c] * 7 3)))
             }).to have_output("true")
    end 
  end

  describe "update" do
    it "works (0 args)" do
      expect(%Q{
             (print (= {:a 42} (update {:a 41} :a inc)))
             }).to have_output("true")
    end 

    it "works (1 arg)" do
      expect(%Q{
             (print (= {:a 42} (update {:a 21} :a * 2)))
             }).to have_output("true")
    end 

    it "works (2 args)" do
      expect(%Q{
             (print (= {:a 42} (update {:a 2} :a * 7 3)))
             }).to have_output("true")
    end 
  end

  describe "get-in" do
    it "works" do
      expect(%Q{
             (print (get-in {:a {:b {:c 42}}} [:a :b :c]))
             (print (get-in {:a {:b {:c 42}}} [:a :b :skeletor] "nope"))
             }).to have_output(%w(42 nope))
    end
  end
end

