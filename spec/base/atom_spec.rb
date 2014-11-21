
RSpec.describe "Language", "atom" do
  describe "deref" do
    it "works (@ operator)" do
      expect(%Q{
            (let [a (atom 42)]
              (print @a))
            }).to have_output("42")
    end

    it "works (deref call)" do
      expect(%Q{
            (let [a (atom 42)]
              (print (deref a)))
            }).to have_output("42")
    end
  end

  describe "reset!" do
    it "changes the atom's value" do
      expect(%Q{
            (let [a (atom 42)]
              (reset! a 12)
              (print @a))
            }).to have_output("12")
    end

    it "returns newval" do
      expect(%Q{
            (let [a (atom 42)]
              (print (reset! a 12)))
            }).to have_output("12")
    end
  end

  describe "swap!" do
    it "works (no arg)" do
      expect(%Q{
            (let [a (atom 42)]
              (swap! a inc)
              (print @a))
            }).to have_output("43")
    end

    it "works (1 arg)" do
      expect(%Q{
            (let [a (atom 18)]
              (swap! a + 24)
              (print @a))
            }).to have_output("42")
    end

    it "works (2 args)" do
      expect(%Q{
            (let [a (atom 18)]
              (swap! a + 6 18)
              (print @a))
            }).to have_output("42")
    end

    it "works (entirely too many args)" do
      expect(%Q{
            (let [a (atom 18)]
              (swap! a + 1 1 1 1 1 1 3 3 3 3 3 3)
              (print @a))
            }).to have_output("42")
    end

    it "returns newval" do
      expect(%Q{
            (let [a (atom 42)]
              (print (swap! a inc)))
            }).to have_output("43")
    end
  end

  describe "watches" do
    it "calls a watch on reset and swap with the right arguments" do
      expect(%Q{
            (let [a (atom 42)]
              (add-watch a :foobar
                           (fn [key ref old kid]
                             (print (name key) old kid)))
              (reset! a 43)
              (swap! a dec))
            }).to have_output("foobar 42 43 foobar 43 42")
    end
  end
end

