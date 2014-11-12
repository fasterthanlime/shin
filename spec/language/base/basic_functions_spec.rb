
RSpec.describe "Language", "basic functions" do
  it "has working nil?" do
    expect(%Q{(print (nil? nil))}).to have_output("true")
    expect(%Q{(print (nil? 42))}).to have_output("false")
  end
end

