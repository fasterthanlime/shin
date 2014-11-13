
RSpec.describe "Language", "atom" do
  it "can create and deref an atom" do
    expect(%Q{
           (let [a (atom 42)]
             (print @a))
           }).to have_output("42")
  end
end

