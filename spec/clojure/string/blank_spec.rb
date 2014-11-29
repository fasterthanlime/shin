
RSpec.describe "clojure.string", "blank?" do
  it "works" do
    expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/blank? nil))
            (print (string/blank? ""))
            (print (string/blank? " \s\t\n\r"))
           }).to have_output(%w(true) * 3)
  end
end
