
RSpec.describe "Language", "hash-map" do
  it "has working get" do
    ["a", "b", "c"].each_with_index do |k, i|
      expect(%Q{ (print (get {:a 1 :b 2 :c 3} :#{k})) }).to have_output("#{i + 1}")
    end
  end

  it "is callable" do
    ["a", "b", "c"].each_with_index do |k, i|
      expect(%Q{ (print ({:a 1 :b 2 :c 3} :#{k})) }).to have_output("#{i + 1}")
    end
  end

  it "has working seq" do
    expect(%Q{
           (print (reduce (fn [acc [k v]] (+ acc v)) 0 (seq {:a 1 :b 2 :c 3})))
           }).to have_output("6")
  end

  %w(map coll seqable associative counted reduceable).each do |property|
    it "satisfies #{property}?" do
      expect("(print (#{property}? {:a :Abaca}))").to have_output("true")
    end
  end
end

