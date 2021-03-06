
RSpec.describe "Language", "equals" do
  it "compares two numbers" do
    expect("(print (= 47 47))").to  have_output("true")
    expect("(print (= 47 123))").to have_output("false")
  end

  it "compares two strings" do
    expect(%q{(print (= "ancient oak" "ancient oak"))}).to  have_output("true")
    expect(%q{(print (= "ancient oak" "mori"))}).to have_output("false")
  end

  it "compares two lists" do
    expect(%q{(print (= '(1 2 3) '(1 2 3)))}).to  have_output("true")
    expect(%q{(print (= '(1 2 3) '(1 2)))}).to    have_output("false")
    expect(%q{(print (= '(1 4) '(1 2)))}).to    have_output("false")
  end

  it "compares two vectors" do
    expect(%q{(print (= [1 2 3] [1 2 3]))}).to  have_output("true")
    expect(%q{(print (= [1 2 3] [1 2]))}).to    have_output("false")
    expect(%q{(print (= [1 4] [1 2]))}).to    have_output("false")
  end
  
  it "compares two maps" do
    expect(%q{(print (= {:b 2 :a 1} {:a 1 :b 2}))}).to  have_output("true")
    expect(%q{(print (= {:a 1} {:a 1 :b 2}))}).to    have_output("false")
    expect(%q{(print (= {:b 2 :a 1} {:a 1}))}).to    have_output("false")
    expect(%q{(print (= {:a 1} {:a 2}))}).to    have_output("false")
  end
end

