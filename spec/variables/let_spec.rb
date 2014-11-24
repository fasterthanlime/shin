
RSpec.describe "Language", "let" do
  it "allows empty lets" do
    expect(%Q{ (let []) }).to have_output("")
    expect(%Q{ (let [] (print "Pointless?")) }).to have_output("Pointless?")
  end

  it "lets and accesses a simple variable" do
    expect(%Q{
           (let [band "Pomplamoose"] (print band))
           }).to have_output("Pomplamoose")
  end

  it "lets shadows but leaves outer intact (values)" do
    expect(%Q{
           (let [a "outer"]
             (print a)
             (let [a "inner"]
               (print a))
             (print a))
           }).to have_output("outer inner outer")
  end

  it "lets shadows but leaves outer intact (functions)" do
    expect(%Q{
           (let [a #(str "outer")]
             (print (a))
             (let [a #(str "inner")]
               (print (a)))
             (print (a)))
           }).to have_output("outer inner outer")
  end

  it "cascading let" do
    expect(%Q{
           (let [a "Boromir"
                 b a]
            (print b))
           }).to have_output("Boromir")
  end

  it "nested lets" do
    expect(%Q{
           (let [{a :m b :m c :m d :m} {:m "Meeeep"}]
             (let [a 1] (let [b 2] (let [c 3] (let [d 4] (print a b c d))))))
           }).to have_output("1 2 3 4")
  end

  it "lets and accesses multiple variables" do
    expect(%Q{
           (let [band "Pomplamoose"
                 status "awesome"
                 count 2]
            (print band count status))
           }).to have_output("Pomplamoose 2 awesome")
  end

  it "raises on invalid let forms" do
    expect { expect(%Q{(let)}).to have_output("") }.to raise_error(Shin::SyntaxError)
    expect { expect(%Q{(let [a 2 woops])}).to have_output("") }.to raise_error(Shin::SyntaxError)
  end

  it "raises on self-referential let" do
    expect do
      expect(%Q{
            (let [inner (fn [x]
                          (if (< x 10)
                            (inner (inc x))
                            x))]
              (print (inner 0)))
            }).to have_output("10")
    end.to raise_error(V8::Error)
  end
end


