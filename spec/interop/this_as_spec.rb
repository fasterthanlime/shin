
RSpec.describe "Language", "this-as" do
  it "works" do
    expect(%Q{
            (let [f (fn []
                      (this-as c
                        #(print (.-kalamazoo c))))
                  o {$ :kalamazoo "Wallclock" }
                  fi (.apply f o [$])]
              (fi))
            }).to have_output("Wallclock")
  end
end

