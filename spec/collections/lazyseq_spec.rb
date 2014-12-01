
RSpec.describe "Language", "lazy-seq" do
  it "doesn't compute unless it has to" do
    expect(%Q{
            (let [step (fn [n]
                          (when (pos? n)
                            (print n)
                            (recur (dec n))))
                  sq (lazy-seq (step 5))]
              (satisfies? sq ISeq))
           }).to have_output([])
  end

  it "does compute when needed" do
    expect(%Q{
            (let [step (fn [n]
                          (when (pos? n)
                            (print n)
                            (recur (dec n))))
                  sq (lazy-seq (step 5))]
              (doall sq))
           }).to have_output(%w(5 4 3 2 1))
  end
end

