
RSpec.describe "Language", "reduce-kv" do
  it "works on vectors" do
    expect(%Q{
             (let [f (fn [o k v] (cons [k v] o))
                   v ["a" "b" "c"]]
               (print (pr-str (reduce-kv f nil v))))
             }).to have_output('([2 "c"] [1 "b"] [0 "a"])')
  end

  it "works on maps" do
    expect(%Q{
             (let [f (fn [o k v] (cons [k v] o))
                   m {:a "a" :b "b" :c "c"}]
               (print (pr-str (reduce-kv f nil m))))
             }).to have_output('([:c "c"] [:b "b"] [:a "a"])')
  end
end


