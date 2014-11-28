
RSpec.describe "Language", "list" do
  it "has working last" do
    expect(%Q{ (print (last  '(1 2 3))) }).to have_output("3")
  end

  it "has working first" do
    expect(%Q{ (print (first '(1 2 3))) }).to have_output("1")
  end

  it "has working nth" do
    [1, 2, 3].each do |i|
      expect(%Q{ (print (nth '(1 2 3) #{i - 1})) }).to have_output("#{i}")
    end
  end

  it "has working count" do
    expect(%Q{ (print (count '(1 2 3))) }).to have_output("3")
  end

  %w(list seq coll sequential counted reduceable seqable).each do |property|
    it "satisfies #{property}?" do
      expect("(print (#{property}? '(1 2 3)))").to have_output("true")
    end
  end
end
