
RSpec.describe "clojure.string" do

  # N.B: quadruple-quotation is frequent in these tests because Ruby does
  # escaping too!
  
  describe "split" do
    it "works (no limit)" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (let [m (string/split "No Country for Old Men" #" ")]
              (doall (map print m)))
      }).to have_output(["No", "Country", "for", "Old", "Men"])
    end

    it "works (limit)" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (let [m (string/split "No Country for Old Men" #" " 3)]
              (doall (map print m)))
      }).to have_output(["No", "Country", "for Old Men"])
    end
  end

  it "split-lines" do
    expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (let [s "A coder alone\nNo spec in sight to guide him\nDanger is afoot"
                  m (string/split-lines s)]
              (doall (map print m)))
           }).to have_output(["A coder alone", "No spec in sight to guide him", "Danger is afoot"])
  end
end

