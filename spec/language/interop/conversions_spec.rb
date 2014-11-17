
RSpec.describe "Language", "conversions" do
  describe "clj->js" do
    it "works on strings" do
      expect(%Q{ (print (clj->js "Hello")) }).to have_output("Hello")
    end

    it "works on numbers" do
      expect(%Q{ (print (clj->js 42)) }).to have_output("42")
    end

    it "works on lists" do
      expect(%Q{ (print (aget (clj->js '("one" "two" "three")) 1)) }).to have_output("two")
    end

    it "works on vectors" do
      expect(%Q{ (print (aget (clj->js ["one" "two" "three"]) 1)) }).to have_output("two")
    end

    it "works on maps" do
      expect(%Q{ (print (aget (clj->js {"ruby" "Ruby" "cpp" "C++"}) "ruby")) }).to have_output("Ruby")
    end
  end
end




