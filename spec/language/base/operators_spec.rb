
RSpec.describe "Language", "operators" do
  it "has working +" do
    expect("(print (+ 22 20))").to have_output("42")
    expect("(print (+ 11 30 2))").to have_output("43")
  end

  it "has working -" do
    expect("(print (- 50 8))").to have_output("42")
    expect("(print (- 100 2 1))").to have_output("97")
  end

  it "has working *" do
    expect("(print (* 2 10))").to have_output("20")
    expect("(print (* 2 10 30))").to have_output("600")
  end

  it "has working <" do
    expect("(print (< 1 2))").to have_output("true")
    expect("(print (< 1 2 3))").to have_output("true")
    expect("(print (< 2 1))").to have_output("false")
  end

  it "has working =" do
    expect('(print (= 97 97))').to have_output("true")
    expect('(print (= "banana" "banana"))').to have_output("true")
    expect('(print (= (list 1 2 3) (list 1 2 3)))').to have_output("true")
    expect('(print (= (vector 1 2 3) (vector 1 2 3)))').to have_output("true")
    expect('(print (= 97 "banana"))').to have_output("false")
    expect('(print (= 97 (list 1 2 3)))').to have_output("false")
  end

  it "has working <=" do
    expect("(print (<= 1 2))").to have_output("true")
    expect("(print (<= 1 1))").to have_output("true")
    expect("(print (<= 1 2 3))").to have_output("true")
    expect("(print (<= 1 1 3))").to have_output("true")
    expect("(print (<= 2 1))").to have_output("false")
  end

  it "has working >=" do
    expect("(print (>= 2 1))").to have_output("true")
    expect("(print (>= 2 2))").to have_output("true")
    expect("(print (>= 3 2 1))").to have_output("true")
    expect("(print (>= 3 2 2))").to have_output("true")
    expect("(print (>= 1 2))").to have_output("false")
  end

  it "has working mod" do
    expect("(print (mod 120 13))").to have_output("3")
    expect("(print (mod 2048 999))").to have_output("50")
  end
end

