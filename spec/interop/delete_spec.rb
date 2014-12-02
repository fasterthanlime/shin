
RSpec.describe "Language", "js-delete" do
  it "works" do
    expect(%Q{
            (let [o {$ :a "Yay"}]
              (print (.hasOwnProperty o "a"))
              (js-delete o "a")
              (print (.hasOwnProperty o "a")))
            }).to have_output(%w(true false))
  end
end


