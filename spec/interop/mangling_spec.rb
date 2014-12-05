
RSpec.describe "Language", "mangling" do
  it "js-arguments" do
    expect(%Q{
           (let [f (fn [] (print (aget js-arguments 0)))]
             (f "hello"))
           }).to have_output(%w(hello))
  end
end
