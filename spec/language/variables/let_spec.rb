
RSpec.describe "Language", "let" do
  it "lets and accesses a simple variable" do
    expect(%Q{
           (let [band "Pomplamoose"] (print band))
           }).to have_output("Pomplamoose")
  end

  it "raises on invalid let forms" do
    expect { expect(%Q{(let)}).to have_output("") }.to raise_error
  end
end


