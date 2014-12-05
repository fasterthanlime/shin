
RSpec.describe "Language", "builtins" do
  it "has working when" do
    expect(%Q{
           (when true (print "1") (print "2"))
           }).to have_output(%w(1 2))
  end

  it "has working when-not" do
    expect(%Q{
           (when-not false (print "1") (print "2"))
           }).to have_output(%w(1 2))
  end

  it "has working if-not" do
    expect(%Q{
           (if-not true  (print "1") (print "2"))
           (if-not false (print "3") (print "4"))
           }).to have_output(%w(2 3))
  end

  it "has working when-let" do
    expect(%Q{
           (when-let [s "1"] (print s) (print s))
           }).to have_output(%w(1 1))
  end

  it "has working when-some" do
    expect(%Q{
           (when-some [s "1"] (print s))
           (when-some [s nil] (print s))
           }).to have_output(%w(1))
  end

  it "has working if-let" do
    expect(%Q{
           (if-let [s "s"] (print 1 s) (print 2))
           (if-let [s nil] (print 3 s) (print 4))
           }).to have_output(["1 s", "4"])
  end

  it "has working assert (positive)" do
    expect(%Q{
          (assert true)
          }).to have_output("")
  end

  it "has working assert (negative)" do
    expect do
      expect(%Q{
            (assert false)
            }).to have_output("")
    end.to raise_error(V8::Error)
  end

  describe "has working case" do
    it "no default" do
      expect(%Q{
          (defn foobar [i]
            (case i
              0 "My"
              1 "heart"
              2 "is"))
           (print (foobar 0))
           (print (foobar 1))
           (print (foobar 2))
           (print (nil? (foobar 3)))
             }).to have_output(%w(My heart is true))
    end

    it "with default" do
      expect(%Q{
          (defn foobar [i]
            (case i
              0 "My"
              1 "heart"
              2 "is"
              "you"))
           (print (foobar 0))
           (print (foobar 1))
           (print (foobar 2))
           (print (foobar 3))
             }).to have_output(%w(My heart is you))
    end

    it "with multiple constants" do
      expect(%Q{
          (defn foobar [i]
            (case i
              (0 1) "nothing,"
              2 "will ever be the same"))
           (print (foobar 0))
           (print (foobar 1))
           (print (foobar 2))
             }).to have_output("nothing, nothing, will ever be the same")
    end
  end
end

