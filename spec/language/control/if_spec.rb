
RSpec.describe "Language", "if" do
  it "has working if (statement)" do
    expect(%Q{(if true  (print "yes") (print "no"))}).to have_output("yes")
    expect(%Q{(if false (print "yes") (print "no"))}).to have_output("no")
  end

  it "has working if (expression)" do
    expect(%Q{(print (if true  "yes" "no"))}).to have_output("yes")
    expect(%Q{(print (if false "yes" "no"))}).to have_output("no")
  end
end

