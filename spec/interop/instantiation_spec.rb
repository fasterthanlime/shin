
RSpec.describe "Language", "instantiation" do
  it "instantiates RegExp and plays around with it" do
    expect(%Q{
            (let [r (RegExp. "[A-Z]")]
              (print (.test r "F"))
              (print (.test r "3")))
           }).to have_output("true false")
  end
end
