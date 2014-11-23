
RSpec.describe "Language", "def" do
  it "defines and access a simple variable" do
    expect(%Q{
           (def band "Pomplamoose")
           (print band)
           }).to have_output("Pomplamoose")
  end

  it "raises on invalid def forms" do
    expect { expect(%Q{(def)}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(def name)}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(def name "Hello" expr woops)}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(def name woops "John doe")}).to have_output("") }.to raise_error(Shin::SyntaxError)
  end
end


