
RSpec.describe "Language", "vector" do
  it "has working last" do
    expect(%Q{ (print (last  (vector 1 2 3))) }).to have_output("3")
  end

  it "has working first" do
    expect(%Q{ (print (first (vector 1 2 3))) }).to have_output("1")
  end

  it "has working nth" do
    [1, 2, 3].each do |i|
      expect(%Q{ (print (nth (vector 1 2 3) #{i - 1})) }).to have_output("#{i}")
    end
  end

  %w(vector collection sequential associative counted indexed reduceable seqable reversible).each do |property|
    it "satisfies #{property}?" do
      expect("(print (#{property}? (vector 1 2 3)))").to have_output("true")
    end
  end
end

