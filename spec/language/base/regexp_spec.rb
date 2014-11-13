
RSpec.describe "Language", "regexp" do
  it "has working re-find (without re-matcher)" do
    expect(%Q{
           (print (= "A" (re-find #"[A-Z]" "A")))
           (print (= "F" (re-find #"[A-Z]" "123F123")))
           }).to have_output("true true")
  end

  it "has working re-matches" do
    expect(%Q{
           (print (nil? (re-matches #"[A-Z]" "Awoops")))
           (print (= "A" (re-matches #"[A-Z]" "A")))
           (print (= (vector "A123" "A") (re-matches #"([A-Z]).*" "A123")))
           }).to have_output("true true true")
  end
end


