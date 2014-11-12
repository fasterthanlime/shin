
RSpec.describe "Language", "def" do
  it "defines and access a simple variable" do
    expect(%Q{
           (def band "Pomplamoose")
           (print band)
           }).to have_output("Pomplamoose")
  end

  it "raises on invalid def forms" do
    expect { expect(%Q{(def)}).to have_output("") }.to raise_error
    expect { expect(%Q{(def name)}).to have_output("") }.to raise_error
    expect { expect(%Q{(def name "Hello" expr woops)}).to have_output("") }.to raise_error
    expect { expect(%Q{(def name not-a-string "John doe")}).to have_output("") }.to raise_error
  end
end


