
RSpec.describe "Language" do
  describe "peek" do
    it "works on vectors" do
      expect(%Q{ (print (peek [1 2 3])) }).to have_output("3")
    end

    it "works on lists" do
      expect(%Q{ (print (peek '(1 2 3))) }).to have_output("1")
    end
  end

  describe "pop" do
    it "works on vectors" do
      expect(%Q{ (print (= [1 2] (pop [1 2 3]))) }).to have_output("true")
    end

    it "works on lists" do
      expect(%Q{ (print (= '(2 3) (pop '(1 2 3)))) }).to have_output("true")
    end
  end
end


