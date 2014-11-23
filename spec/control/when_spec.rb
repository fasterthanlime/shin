
RSpec.describe "Language", "if" do
  it "has working when (positive)" do
    expect(%Q{
      (when (> 3 2) (print "yes") (print "yay"))
           }).to have_output("yes yay")
  end

  it "has working when (negative)" do
    expect(%Q{
      (when (< 3 2) (print "yes") (print "yay"))
           }).to have_output("")
  end
end


