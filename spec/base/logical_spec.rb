
RSpec.describe "Language", "logical operators" do
  it "has working and" do
    expect(%Q{
           (print (and true))
           (print (and false))
           (print (and true true))
           (print (and true true true))
           (print (and true true false))
           }).to have_output(%w(true false true true false))
  end

  it "has working or" do
    expect(%Q{
           (print (or true))
           (print (or false))
           (print (or true true))
           (print (or true true true))
           (print (or true true false))
           (print (or false false false))
           }).to have_output(%w(true false true true true false))
  end

  it "logical operators exist as functions" do
    expect(%Q{
           (defn bop [op & args] (print (apply op args)))
           (bop and  true true true true)
           (bop or  false false false true)

           (bop and  true true true false)
           (bop or  false false false false)
           }).to have_output(['true'] * 2 + ['false'] * 2)
  end
end


