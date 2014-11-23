
RSpec.describe "Language", "destructuring" do
  describe "on vectors" do
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

    it "works when nested" do
      expect(%Q{
      (let [[[a b] c [[d] [e [f]]]]  [[1 2] 3 [[4] [5 [6]]]]]
        (print a b c d e f))
             }).to have_output("1 2 3 4 5 6")
    end
  end

  describe "on maps" do
    it "captures individual elements" do
      expect(%Q{
             (let [m                {:a 1 :b 2 :c 3 :d 4}
                   {a :a b :b c :c} m]
               (print a b c))
             }).to have_output("1 2 3")
    end

    it "works with :keys directive" do
      expect(%Q{
             (let [m                {:a 1 :b 2 :c 3 :d 4}
                   {:keys [a b c]} m]
               (print a b c))
             }).to have_output("1 2 3")
    end

    it "works with :strs directive" do
      expect(%Q{
             (let [m                {"a" 1 "b" 2 "c" 3 "d" 4}
                   {:strs [a b c]} m]
               (print a b c))
             }).to have_output("1 2 3")
    end

    it "works with :syms directive" do
      expect(%Q{
             (let [m                {'a 1 'b 2 'c 3 'd 4}
                   {:syms [a b c]} m]
               (print a b c))
             }).to have_output("1 2 3")
    end
  end
end

