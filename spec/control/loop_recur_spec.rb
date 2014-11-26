
RSpec.describe "Language", "loop/recur" do
  it "has working loop/recur" do
    expect(%Q{
           (loop [i 1]
             (when (<= i 5)
               (print i)
               (recur (inc i))))
           }).to have_output("1 2 3 4 5")
  end

  describe "different modes" do
    it "works in return mode" do
      expect(%Q{
            (print ((fn []
                     (loop [i 1
                            r ""]
                       (if (<= i 5)
                         (recur (inc i) (str r i))
                         r)))))
            
            }).to have_output("12345")
    end

    it "works in statement mode" do
      expect(%Q{
            ((fn []
              (loop [i 1
                    r ""]
                (if (<= i 5)
                  (recur (inc i) (str r i))
                  (print r)))
              nil))
            }).to have_output("12345")
    end

    it "works in expression mode" do
      expect(%Q{
            (print
              (loop [i 1
                    r ""]
                (if (<= i 5)
                  (recur (inc i) (str r i))
                  r)))
            }).to have_output("12345")
    end
  end
end

