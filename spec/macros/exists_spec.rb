
RSpec.describe "Language", "exists" do
  it "has working exists?" do
    expect(%Q{
           (let [to-be 42]
             (print (exists? to-be) (exists? not-to-be)))
           }).to have_output("true false")
  end
end

