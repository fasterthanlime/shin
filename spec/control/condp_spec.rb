
RSpec.describe "Language", "condp" do
  it "works (expression)" do
    expect(%Q{
           (defn foo [x]
             (print
               (condp > x
                1 "a"
                2 "b"
                3 "c"
                :else   "d")))
           (foo 0) (foo 1) (foo 2) (foo 3)
           }).to have_output("a b c d")
  end

  it "works (statement)" do
    expect(%Q{
           (defn foo [x]
             (condp > x
               1 (print "a")
               2 (print "b")
               3 (print "c")
               :else   (print "d"))
             nil)
           (foo 0) (foo 1) (foo 2) (foo 3)
           }).to have_output("a b c d")
  end

  it "works (return)" do
    expect(%Q{
           (defn bar [x]
             (condp > x
               1 "a"
               2 "b"
               3 "c"
               :else   "d"))
           (defn foo [x] (print (bar x)))
           (foo 0) (foo 1) (foo 2) (foo 3)
           }).to have_output("a b c d")
  end
end



