
RSpec.describe "Compiler", "defn" do
  it "defines and calls a simple function" do
    expect(%Q{
           (defn hello [] (print "Hello"))
           (hello)
           }).to have_output("Hello")
  end
end

