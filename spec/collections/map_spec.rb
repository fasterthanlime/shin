
RSpec.describe "Language", "map" do
  it "works with vectors" do
    expect(%Q{ (print (= [2 4 6 8] (map (fn [x] (* x 2)) [1 2 3 4]))) }).to have_output("true")
  end

  it "works with lists" do
    expect(%Q{ (print (= '(2 4 6 8) (map (fn [x] (* x 2)) '(1 2 3 4)))) }).to have_output("true")
  end
end


