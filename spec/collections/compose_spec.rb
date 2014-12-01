

RSpec.describe "Language" do
  it "repeat works" do
    expect(%Q{ (print (= '(5 5 5) (take 3 (repeat 5)))) }).to have_output("true")
  end

  it "replicate works" do
    expect(%Q{ (print (= '(5 5 5) (replicate 3 5))) }).to have_output("true")
  end

  it "repeatedly works" do
    expect(%Q{ (dorun (repeatedly 3 #(print "Hello"))) }).to have_output(%w(Hello Hello Hello))
    expect(%Q{ (dorun (take 3 (repeatedly #(print "Hello")))) }).to have_output(%w(Hello Hello Hello))
  end

  it "concat works" do
    expect(%Q{ (print (= '() (concat))) }).to have_output("true")
    expect(%Q{ (print (= '(1 2 3 4) (concat '(1 2) '(3 4)))) }).to have_output("true")
    expect(%Q{ (print (= '(1 2 3 4 5 6) (concat '(1) '(2 3) '(4 5 6)))) }).to have_output("true")
  end

  it "interleave works" do
    expect(%Q{ (print (= '(1 2 1 2 1 2) (take 6 (interleave (repeat 1) (repeat 2))))) }).to have_output("true")
    expect(%Q{ (print (= '(1 2 3 1 2 3) (take 6 (interleave (repeat 1) (repeat 2) (repeat 3))))) }).to have_output("true")
  end

  it "interpose works" do
    expect(%Q{ (print (= '(1 0 2 0 3) (interpose 0 '(1 2 3)))) }).to have_output("true")
  end

  it "range works" do
    expect(%Q{ (print (= '(0 1 2 3 4 5) (range 0 6))) }).to have_output("true")
    expect(%Q{ (print (= '(0 1 2 3 4 5) (range 0 6 1))) }).to have_output("true")
    expect(%Q{ (print (= '(0 2 4) (range 0 6 2))) }).to have_output("true")
    expect(%Q{ (print (= '(0 1 2 3 4 5) (take 6 (range)))) }).to have_output("true")
  end
end

