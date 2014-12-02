
RSpec.describe "Language", "merge" do
  it "works on two maps" do
    expect(%Q{
             (let [m1 {:a 1 :b 2}
                   m2 {:c 3 :d 4}
                   mm (merge m1 m2)]
               (print (= mm {:a 1 :b 2 :c 3 :d 4})))
             }).to have_output('true')
  end

  it "works on three maps" do
    expect(%Q{
             (let [m1 {:a 1 :b 2}
                   m2 {:c 3 :d 4}
                   m3 {:e 5 :f 6}
                   mm (merge m1 m2 m3)]
               (print (= mm {:a 1 :b 2 :c 3 :d 4 :e 5 :f 6})))
             }).to have_output('true')
  end

  it "works on three maps (overlap)" do
    expect(%Q{
             (let [m1 {:a 1 :b "wazoo"}
                   m2 {:b 2 :c "weepe"}
                   m3 {:c 3}
                   mm (merge m1 m2 m3)]
               (print (= mm {:a 1 :b 2 :c 3})))
             }).to have_output('true')
  end
end

