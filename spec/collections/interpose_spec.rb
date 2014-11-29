
RSpec.describe "Language", "interpose" do
  it "works" do
    expect(%Q{
           (print (= '(1 0 2 0 3) (interpose 0 '(1 2 3))))
           }).to have_output("true")
  end

  it "works (one elems)" do
    expect(%Q{
           (print (= '(1) (interpose 0 '(1))))
           }).to have_output("true")
  end
end

