
RSpec.describe "clojure.string", "replace" do
  # N.B: quadruple-quotation is frequent in these tests because Ruby does
  # escaping too!
  
  it "works with strings" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/replace "Unladen py\\\\thon" "py\\\\thon" "swallow"))
    }).to have_output("Unladen swallow")
  end

  it "works with regexps and string" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/replace "Unladen py\\\\thon" #"py.*n" "swallow"))
    }).to have_output("Unladen swallow")
  end

  it "works with regexps and function" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/replace "Unladen py\\\\thon" #"py.*n" #(str % ", y'all")))
    }).to have_output("Unladen py\\thon, y'all")
  end
end


