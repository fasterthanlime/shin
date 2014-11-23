
RSpec.describe "Language", "destructuring" do
  describe "on vectors/lists" do
    it "captures all elements at once" do
      expect(%Q{
             (let [r1     [1 2 3]
                   [& r2] [1 2 3]]
               (print (= r1 r2)))
             }).to have_output("true")
    end

    it "captures individual elements" do
      expect(%Q{
             (let [r1      [1 2 3]
                   [a b c] r1
                   r2      [a b c]]
               (print (= r1 r2)))
             }).to have_output("true")
    end

    it "captures both individual elements and rest" do
      expect(%Q{
             (let [r1      [1 2 3]
                   [a & rr] r1
                   [b c]    rr
                   r2      [a b c]]
               (print (= r1 r2)))
             }).to have_output("true")
    end
  end
end

