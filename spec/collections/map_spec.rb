
RSpec.describe "Language", "map" do
  it "works with vectors" do
    expect(%Q{ (print (= '(2 4 6 8) (map (fn [x] (* x 2)) [1 2 3 4]))) }).to have_output("true")
  end

  it "works with lists" do
    expect(%Q{ (print (= '(2 4 6 8) (map (fn [x] (* x 2)) '(1 2 3 4)))) }).to have_output("true")
  end

  describe "map-indexed" do
    it "works" do
      expect(%Q{ (print (pr-str (map-indexed (fn [i x] (* x i)) '(1 2 3 4)))) }).to have_output("(0 2 6 12)")
    end
  end
end


