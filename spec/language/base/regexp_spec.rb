
RSpec.describe "Language", "regexp" do
  it "has working re-find" do
    expect(%Q{
           (print (= "A" (re-find #"[A-Z]" "A")))
           (print (= "F" (re-find #"[A-Z]" "123F123")))
           }).to have_output("true true")
  end
end


