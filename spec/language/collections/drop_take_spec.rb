
RSpec.describe "Language" do
  describe "drop" do
    it "works on lists" do
      expect(%Q{ (print (= '(2 3) (drop 1 '(1 2 3)))) }).to have_output("true")
      expect(%Q{ (print (= '(3) (drop 2 '(1 2 3)))) }).to have_output("true")
      expect(%Q{ (print (= '() (drop 3 '(1 2 3)))) }).to have_output("true")
    end

    it "works on vectors" do
      expect(%Q{ (print (= [2 3] (drop 1 [1 2 3]))) }).to have_output("true")
      expect(%Q{ (print (= [3] (drop 2 [1 2 3]))) }).to have_output("true")
      expect(%Q{ (print (= [] (drop 3 [1 2 3]))) }).to have_output("true")
    end
  end
end

