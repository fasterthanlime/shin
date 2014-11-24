
RSpec.describe "Language", "hash-map" do
  it "has working get" do
    ["a", "b", "c"].each_with_index do |k, i|
      expect(%Q{ (print (get {:a 1 :b 2 :c 3} :#{k})) }).to have_output("#{i + 1}")
    end
  end

  it "is callable" do
    ["a", "b", "c"].each_with_index do |k, i|
      expect(%Q{ (print ({:a 1 :b 2 :c 3} :#{k})) }).to have_output("#{i + 1}")
    end
  end
end

