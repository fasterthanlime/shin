
RSpec.describe "Language", "do" do
  it "has working do (statement)" do
    expect(%Q{(do (print "a") (print "b"))}).to have_output("a b")
  end

  it "has working do (expression)" do
    expect(%Q{(print (do (print "a") "b"))}).to have_output("a b")
  end
end

