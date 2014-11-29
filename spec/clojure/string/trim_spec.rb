
RSpec.describe "clojure.string" do

  it "trim" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/trim "\t \n  halp  \t   \n\n"))
           }).to have_output("halp")
  end

  it "triml" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/triml "\t \n  halp  \t   \n\n"))
           }).to have_output("halp  \t   \n\n")
  end

  it "trimr" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/trimr "\t \n  halp  \t   \n\n"))
           }).to have_output("\t \n  halp")
  end

end

