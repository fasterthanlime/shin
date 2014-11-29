
RSpec.describe "Language", "declare" do
  it "works" do
    expect(%Q{
           (declare a b c)
           (print (exists? a))
           (print (exists? b))
           (print (exists? c))
           }).to have_output(%w(true) * 3)
  end
end

