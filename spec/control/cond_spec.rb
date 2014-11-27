
RSpec.describe "Language", "cond" do
  it "works (expression)" do
    expect(%Q{
           (defn foo [x]
             (print
               (cond
                (= x 0) "a"
                (= x 1) "b"
                (= x 2) "c"
                :else   "d")))
           (foo 0) (foo 1) (foo 2) (foo 3)
           }).to have_output("a b c d")
  end

  it "works (statement)" do
    expect(%Q{
           (defn foo [x]
             (cond
               (= x 0) (print "a")
               (= x 1) (print "b")
               (= x 2) (print "c")
               :else   (print "d"))
             nil)
           (foo 0) (foo 1) (foo 2) (foo 3)
           }).to have_output("a b c d")
  end

  it "works (return)" do
    expect(%Q{
           (defn bar [x]
             (cond
               (= x 0) "a"
               (= x 1) "b"
               (= x 2) "c"
               :else   "d"))
           (defn foo [x] (print (bar x)))
           (foo 0) (foo 1) (foo 2) (foo 3)
           }).to have_output("a b c d")
  end
end


