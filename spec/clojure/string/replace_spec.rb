
RSpec.describe "clojure.string" do

  # N.B: quadruple-quotation is frequent in these tests because Ruby does
  # escaping too!
  
  describe "replace" do
    it "works with strings" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/replace "Unladen py\\\\thon py\\\\thon" "py\\\\thon" "swallow"))
      }).to have_output("Unladen swallow swallow")
    end

    it "works with regexps and string" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/replace "Unladen py\\\\thon py\\\\thon" #"py.*?n" "swallow"))
      }).to have_output("Unladen swallow swallow")
    end

    it "works with regexps and function" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/replace "Unladen py\\\\thon py\\\\thon" #"py.*?n" #(str % ", y'all")))
      }).to have_output("Unladen py\\thon, y'all py\\thon, y'all")
    end
  end

  describe "replace-first" do
    it "works with strings" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/replace-first "Unladen py\\\\thon py\\\\thon" "py\\\\thon" "swallow"))
      }).to have_output("Unladen swallow py\\thon")
    end

    it "works with regexps and string" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/replace-first "Unladen py\\\\thon py\\\\thon" #"py.*?n" "swallow"))
      }).to have_output("Unladen swallow py\\thon")
    end

    it "works with regexps and function" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/replace-first "Unladen py\\\\thon py\\\\thon" #"py.*?n" #(str % ", y'all")))
      }).to have_output("Unladen py\\thon, y'all py\\thon")
    end
  end
end


