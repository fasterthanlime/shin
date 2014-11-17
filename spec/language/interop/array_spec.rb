
RSpec.describe "Language", "array" do
  it "has array literals and aget" do
    expect(%Q{
           (def band [$ "eenie" "meenie" "moe"])
           (print (aget band 0) (aget band 1) (aget band 2))
           }).to have_output("eenie meenie moe")
  end
end



