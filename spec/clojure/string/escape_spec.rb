
RSpec.describe "clojure.string", "escape" do
  it "works" do
    expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (let [cmap {"&" "&amp;"
                        " " "&nbsp;"}
                  s "fun &times"]
              (print (string/escape s cmap)))
           }).to have_output("fun&nbsp;&amp;times")
  end
end

