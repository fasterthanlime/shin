
RSpec.describe "Language", "exceptions" do
  describe "basic functionality" do
    it "does work (simple)" do
      expect(%Q{
             (try
               (print "Before")
               (throw (js/Error. "Blah."))
               (print "After")
               (catch js/Object e
                 (when-not (nil? e) (print "Into"))))
             }).to have_output(%w(Before Into))
    end

    it "does work (multiple clauses)" do
      expect(%Q{
             (defn eek [up]
               (try
                 (print "Before")
                 (throw up)
                 (print "After")
                 (catch js/Array e
                   (print "Array"))
                 (catch js/Object e
                   (print "Object"))))
              (eek #"blup")
              (eek [$ "bleep"])
             }).to have_output(%w(Before Object Before Array))
    end
  end

  describe "various modes" do
    it "works as expression" do
      expect(%Q{
             (print (try "Try"))
             (print (try
                      (throw (js/Error. "Woops."))
                      (catch js/Object e "Catch")))
             }).to have_output(%w(Try Catch))
    end

    it "works as return" do
      expect(%Q{
             (print (#(try "Try")))
             (print (#(try
                      (throw (js/Error. "Woops."))
                      (catch js/Object e "Catch"))))
             }).to have_output(%w(Try Catch))
    end

    it "works as statement" do
      expect(%Q{
             (try (print "Try"))
             (try
               (throw (js/Error. "Woops."))
               (catch js/Object e
                 (print "Catch")))
             nil
             }).to have_output(%w(Try Catch))
    end
  end
end

