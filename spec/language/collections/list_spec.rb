
RSpec.describe "Language", "list" do
  it "has working last" do
    expect(%Q{ (print (last  (list 1 2 3))) }).to have_output("3")
  end

  it "has working first" do
    expect(%Q{ (print (first (list 1 2 3))) }).to have_output("1")
  end

  it "has working nth" do
    [1, 2, 3].each do |i|
      expect(%Q{ (print (nth (list 1 2 3) #{i - 1})) }).to have_output("#{i}")
    end
  end

  %w(list seq collection sequential counted reduceable seqable).each do |property|
    it "satisfies #{property}?" do
      expect("(print (#{property}? (list 1 2 3)))").to have_output("true")
    end
  end
end
