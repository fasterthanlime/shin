
RSpec.describe "Language", "loop/recur" do
  it "has working loop/recur" do
    expect(%Q{
           (loop [i 1]
             (when (<= i 5)
               (print i)
               (recur (inc i))))
           }).to have_output("1 2 3 4 5")
  end
end

