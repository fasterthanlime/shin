
RSpec.describe "Language", "object" do
  it "has object literals and aget" do
    expect(%Q{
           (def dude {$ "name" "buddy holly"
                        "job"  "singer"})
           (print (aget dude "name") (aget dude "job"))
           }).to have_output("buddy holly singer")
  end
end



