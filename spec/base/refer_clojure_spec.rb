
RSpec.describe "Language", "refer-clojure" do

  it "indeeds excludes things" do
    expect do
      expect(%Q{
        (ns cljs.test.refer-clojure
          (:refer-clojure :exclude [atom]))

        (print @(atom nil))
      }).to have_output([])
    end.to raise_error V8::Error, "atom is not defined"
  end

end

