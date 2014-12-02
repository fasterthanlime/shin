
RSpec.describe "Language" do
  it "or works" do
    expect(%Q{
            (print (or nil nil nil nil 3 4))
          }).to have_output("3")
    expect(%Q{
            (print (nil? (or nil nil nil nil)))
          }).to have_output("true")
    expect(%Q{
            (print (nil? (or)))
          }).to have_output("true")
  end

  it "and works" do
    expect(%Q{
            (print (and 1 2 3 4 5 false 6))
          }).to have_output("false")
    expect(%Q{
            (print (and 1 2 3 4 5 6))
          }).to have_output("6")
    expect(%Q{
            (print (and))
          }).to have_output("true")
  end
end


