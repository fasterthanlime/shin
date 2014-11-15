

RSpec.describe "Language", "complement" do
  it "works" do
    expect(%Q{(let [t (fn [] true)
                    f (complement t)]
                (print (not (t)) (f)))}).to have_output("false false")
  end
end

