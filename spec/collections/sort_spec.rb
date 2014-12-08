
RSpec.describe "Language", "sort" do
  it "works (basic)" do
    expect(%Q{
           (print (pr-str (sort [8 3 1 4])))
           }).to have_output('(1 3 4 8)')
  end

  it "works (custom comparator)" do
    expect(%Q{
           (print (pr-str (sort #(if (> %1 %2) -1 (if (< %1 %2) 1 0))  [8 3 1 4])))
           }).to have_output('(8 4 3 1)')
  end
end



