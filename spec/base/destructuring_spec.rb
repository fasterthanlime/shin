
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
                   {d :d :keys [a b c]} m]
               (print a b c d))
             }).to have_output("1 2 3 4")
    end

    it "works with :strs directive" do
      expect(%Q{
             (let [m                {"a" 1 "b" 2 "c" 3 "d" 4}
                   {d "d" :strs [a b c]} m]
               (print a b c d))
             }).to have_output("1 2 3 4")
    end

    it "works with :syms directive" do
      expect(%Q{
             (let [m                {'a 1 'b 2 'c 3 'd 4}
                   {d 'd :syms [a b c]} m]
               (print a b c d))
             }).to have_output("1 2 3 4")
    end

    it "works with :as directive" do
      expect(%Q{
             (let [m                      {:a 1 :b 2 :c 3 :d 4}
                   {:as m2 d :d}          m
                   {a :a b :b c :c}       m2]
               (print a b c))
             }).to have_output("1 2 3")
    end
  end

  # describe "stress test" do
  #   it "works with an example from clojure.org" do
  #     expect(%Q{
  #            (let [{j :j, k :k, i :i, [r s & t :as v] :ivec, :or {i 12 j 13}}
  #                  {:j 15 :k 16 :ivec [22 23 24 25]}]
  #                    [i j k r s t v])
  #            }).to have_output("[12 15 16 22 23 (24 25) [22 23 24 25]]")
  #   end
  # end
end

