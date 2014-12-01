
RSpec.describe "Language", "threading" do

  it "has working -> (threadf)" do
    expect(%Q{
           (print (-> "a b c d"
                      .toUpperCase
                      (.replace "A" "X")
                      (.split " ")
                      (aget 0)))
          }).to have_output("X")
  end

  it "has working ->> (threadl)" do
    expect(%Q{
           (print (->> 2
                      (/ 10)
                      (* 3)
                      (/ 45)))
          }).to have_output("3")
  end

  it "has working some->" do
    expect(%Q{
           (print (some-> {:a {:b 1}}
                          :a
                          (get :b)
                          inc))
          }).to have_output("2")
    expect(%Q{
           (print (nil? (some-> {:a {:b 1}}
                                :a
                                (get :c)
                                inc)))
          }).to have_output("true")
  end

end


