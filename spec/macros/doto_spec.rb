
RSpec.describe "Language", "doto" do

  it "works" do
    expect(%Q{
           (let [arr (doto [$]
                     (.push "a")
                     (.push "b")
                     (.push "c"))]
             (print (aget arr 2)))
          }).to have_output("c")
  end
end

