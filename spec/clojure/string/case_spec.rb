
RSpec.describe "clojure.string" do
  it "has working upper-case" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/upper-case "Well then"))
    }).to have_output("WELL THEN")
  end

  it "has working lower-case" do
    expect(%Q{
           (ns test (:require [clojure.string :as string]))
           (print (string/lower-case "YOU KNOW"))
    }).to have_output("you know")
  end
end

