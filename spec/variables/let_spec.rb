
RSpec.describe "Language", "let" do
  it "allows empty lets" do
    expect(%Q{ (let []) }).to have_output("")
    expect(%Q{ (let [] (print "Pointless?")) }).to have_output("Pointless?")
  end

  it "lets and accesses a simple variable" do
    expect(%Q{
           (let [band "Pomplamoose"] (print band))
           }).to have_output("Pomplamoose")
  end

  it "lets shadows but leaves outer intact" do
    expect(%Q{
           (let [a "outer"]
             (print a)
             (let [a "inner"]
               (print a))
             (print a))
           }).to have_output("outer inner outer")
  end

  it "cascading let" do
    expect(%Q{
           (let [a "Boromir"
                 b a]
            (print b))
           }).to have_output("Boromir")
  end

  it "lets and accesses multiple variables" do
    expect(%Q{
           (let [band "Pomplamoose"
                 status "awesome"
                 count 2]
            (print band count status))
           }).to have_output("Pomplamoose 2 awesome")
  end

  it "raises on invalid let forms" do
    expect { expect(%Q{(let)}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(let [a 2 woops])}).to have_output("") }.to raise_error(Shin::SyntaxError)
  end
end


