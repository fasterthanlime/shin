
RSpec.describe "Language", "map" do
  it "has working get" do
    expect(%Q{ (print (get (hash-map (keyword "ruby") "Ruby" (keyword "cpp") "C++") (keyword "ruby"))) }).to have_output("Ruby")
  end

  %w(map collection associative counted seqable).each do |property|
    it "satisfies #{property}?" do
      expect("(print (#{property}? (hash-map)))").to have_output("true")
    end
  end
end


