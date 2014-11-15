
RSpec.describe "Language", "subvec" do
  it "subvec works (simple)" do
    expect(%q{ (print (= [2 3 4 5] (subvec [1 2 3 4 5 6 7 8] 1 5))) }).to have_output("true")
  end

  it "subvec works (omit end)" do
    expect(%q{ (print (= [4 5 6 7 8] (subvec [1 2 3 4 5 6 7 8] 3))) }).to have_output("true")
  end

  it "subvec works (empty)" do
    expect(%q{
           (let [c (subvec [1 2 3 4 5 6 7 8] 3 3)]
            (print (empty? c))
            (print (= [] c))) 
           }).to have_output("true true")
  end

  it "subvec works (twice)" do
    expect(%q{
           (let [a [1 2 3 4 5 6 7 8]
                 b (subvec a 2 7)
                 c (subvec b 3 5)]
             (print (= b [3 4 5 6 7]))
             (print (= c [6 7])))
           }).to have_output("true true")
  end
end
