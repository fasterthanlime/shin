
RSpec.describe "Language", "threading" do

  it "has working ->" do
    expect(%Q{
           (print (-> "a b c d"
                      .toUpperCase
                      (.replace "A" "X")
                      (.split " ")
                      (aget 0)))
          }).to have_output("X")
  end

  it "has working ->>" do
    expect(%Q{
           (print (->> 2
                      (/ 10)
                      (* 3)
                      (/ 45)))
          }).to have_output("3")
  end

end


