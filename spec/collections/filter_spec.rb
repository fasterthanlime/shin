
RSpec.describe "Language", "reduce" do
  it "works" do
    expect(%Q{ (print (pr-str (filter even? [1 2 3 4]))) }).to have_output("(2 4)")
    expect(%Q{ (print (pr-str (filter odd? [1 2 3 4]))) }).to have_output("(1 3)")
  end
end


