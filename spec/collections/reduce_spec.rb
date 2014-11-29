
RSpec.describe "Language", "reduce" do
  it "works on vectors (+)" do
    expect(%Q{ (print (reduce + [1 2 3])) }).to have_output("6")
  end

  it "works on lists (+)" do
    expect(%Q{ (print (reduce + '(1 2 3))) }).to have_output("6")
  end
end

