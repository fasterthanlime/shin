
RSpec.describe "Language", "atom" do
  it "has a working @ (deref operator)" do
    expect(%Q{
           (let [a (atom 42)]
             (print @a))
           }).to have_output("42")
  end

  it "has a working deref" do
    expect(%Q{
           (let [a (atom 42)]
             (print (deref a)))
           }).to have_output("42")
  end

  it "has a working reset!" do
    expect(%Q{
           (let [a (atom 42)]
             (reset! a 12)
             (print @a))
           }).to have_output("12")
  end

  it "has a working swap (no arg)" do
    expect(%Q{
           (let [a (atom 42)]
             (swap! a inc)
             (print @a))
           }).to have_output("43")
  end

  it "has a working swap (1 arg)" do
    expect(%Q{
           (let [a (atom 18)]
             (swap! a + 24)
             (print @a))
           }).to have_output("42")
  end

  it "has a working swap (2 args)" do
    expect(%Q{
           (let [a (atom 18)]
             (swap! a + 6 18)
             (print @a))
           }).to have_output("42")
  end

  it "has a working swap (entirely too many args)" do
    expect(%Q{
           (let [a (atom 18)]
             (swap! a + 1 1 1 1 1 1 3 3 3 3 3 3)
             (print @a))
           }).to have_output("42")
  end
end

