
RSpec.describe "Language", "escape" do

  it "works with \\t" do
    expect(%Q{
           (print "yeah\\tboy")
           }).to have_output("yeah\tboy")
  end

  it "works with \\n" do
    expect(%Q{
           (print "yeah\\nboy")
           }).to have_output("yeah\nboy")
  end

  it "works with \\\\" do
    expect(%Q{
           (print "yeah\\\\boy")
           }).to have_output("yeah\\boy")
  end

end

