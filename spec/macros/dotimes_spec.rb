
RSpec.describe "Language", "dotimes" do

  it "works" do
    expect(%Q{
           (dotimes [n 3]
             (print "Knock" n)) 
           }).to have_output(["Knock 0", "Knock 1", "Knock 2"])
  end
end


