
RSpec.describe "Language", "operators" do
  it "has working +" do
    expect(%Q{
           (print (+ 22 20))
           (print (+ 11 30 2))
           }).to have_output(%w(42 43))
  end

  it "has working -" do
    expect(%Q{
           (print (- 50 8))
           (print (- 100 2 1))
           }).to have_output(%w(42 97))
  end

  it "has working *" do
    expect(%Q{
           (print (* 10 2))
           (print (* 2 10 30))
           }).to have_output(%w(20 600))
  end

  it "has working <" do
    expect(%Q{
           (print (< 1 2))
           (print (< 1 2 3))
           (print (< 2 1))
           }).to have_output(%w(true true false))
  end

  it "has working = and not=" do
    expect(%Q{
           (defn comp [a b]
             (print (= a b))
             (print (not (not= a b))))
           (comp 97 97)
           (comp "banana" "banana")
           (comp (list 1 2 3) (list 1 2 3))
           (comp (vector 1 2 3) (vector 1 2 3))
           (comp 97 "banana")
           (comp 97 (list 1 2 3))
           }).to have_output(%w(true) * 8 + %w(false) * 4)
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

  it "comparison operators exist as functions" do
    expect(%Q{
           (defn bop [op & args] (print (apply op args)))
           (bop >  9 8 7 6 5 4 3 2 1)
           (bop <  1 2 3 4 5 6 7 8 9)
           (bop >= 9 9 8 8 7 7 6 6 5)
           (bop <= 1 1 2 2 3 3 4 4 5)
           (bop =  1 1 1 1 1 1 1 1 1)

           (bop >  9 8 7 6 0 4 3 2 1)
           (bop <  1 2 3 4 0 6 7 8 9)
           (bop >= 9 9 8 8 0 7 6 6 5)
           (bop <= 1 1 2 2 0 3 4 4 5)
           (bop =  1 1 1 1 0 1 1 1 1)
           }).to have_output(['true'] * 5 + ['false'] * 5)
  end
end

