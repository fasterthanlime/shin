
RSpec.describe "Language", "symbol" do
  it "is callable" do
    ["a", "b", "c"].each_with_index do |k, i|
      expect(%Q{ (print ('#{k} {'a 1 'b 2 'c 3})) }).to have_output("#{i + 1}")
    end
  end
end



