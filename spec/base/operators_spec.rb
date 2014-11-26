
RSpec.describe "Language", "operators" do
  it "has working truthy" do
    expect('(print (truthy true))').to have_output("true")
    expect('(print (truthy 1))').to have_output("true")
    expect('(print (truthy "Hello"))').to have_output("true")
    expect('(print (truthy {$}))').to have_output("true")
    expect('(print (truthy [$]))').to have_output("true")
    expect('(print (truthy nil))').to have_output("false")
    expect('(print (truthy undefined))').to have_output("false")
    expect('(print (truthy false))').to have_output("false")
  end

  it "has working falsey" do
    expect('(print (falsey true))').to have_output("false")
    expect('(print (falsey 1))').to have_output("false")
    expect('(print (falsey "Hello"))').to have_output("false")
    expect('(print (falsey {$}))').to have_output("false")
    expect('(print (falsey [$]))').to have_output("false")
    expect('(print (falsey nil))').to have_output("true")
    expect('(print (falsey undefined))').to have_output("true")
    expect('(print (falsey false))').to have_output("true")
  end

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

  it "has working not=" do
    expect('(print (not= 97 97))').to have_output("false")
    expect('(print (not= "banana" "banana"))').to have_output("false")
    expect('(print (not= (list 1 2 3) (list 1 2 3)))').to have_output("false")
    expect('(print (not= (vector 1 2 3) (vector 1 2 3)))').to have_output("false")
    expect('(print (not= 97 "banana"))').to have_output("true")
    expect('(print (not= 97 (list 1 2 3)))').to have_output("true")
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

