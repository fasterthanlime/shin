
RSpec.describe "clojure.string", "join" do

  describe "join" do
    it "works without separators" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/join ["foo" "bar" "baz"]))
      }).to have_output(["foobarbaz"])
    end

    it "works with separators" do
      expect(%Q{
            (ns test (:require [clojure.string :as string]))
            (print (string/join ", " ["foo" "bar" "baz"]))
      }).to have_output(["foo, bar, baz"])
    end
  end
end

