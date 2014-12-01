
RSpec.describe "Language", "indexed-seq" do
  it "works (reduce)" do
    expect(%Q{
           (let [is (IndexedSeq. [$ 1 2 3 4 5] 0)]
             (print (reduce + is)))
           }).to have_output(%w(15))
  end

  it "works (nth, nthnext)" do
    expect(%Q{
           (let [is (IndexedSeq. [$ 1 2 3 4 5 6 7 8 9] 0)]
             (loop [s is]
               (when s
                 (print (nth s 0) (nth s 1) (nth s 2))
                 (recur (nthnext s 3)))))
           }).to have_output(["1 2 3", "4 5 6", "7 8 9"])
  end

  it "works (destructuring)" do
    expect(%Q{
           (let [is (IndexedSeq. [$ 1 2 3 4 5 6 7 8 9] 0)]
             (loop [s is]
               (when s
                 (let [[a b c & d] s]
                   (print a b c)
                   (recur d)))))
           }).to have_output(["1 2 3", "4 5 6", "7 8 9"])
  end
end

