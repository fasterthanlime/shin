
RSpec.describe "Language", "meta" do
  it "functions" do
    expect(%Q{
           (let [f  (fn [])
                 fm (with-meta f {:key "Xzibit"})]
             (print (nil? (meta f)))
             (print (nil? (meta fm)))
             (print (:key (meta fm))))
           }).to have_output(%w(true false Xzibit))
  end

  it "vectors" do
    expect(%Q{
           (let [v []
                 vm (with-meta v {:key "Xzibit"})]
             (print (nil? (meta v)))
             (print (nil? (meta vm)))
             (print (:key (meta vm))))
           }).to have_output(%w(true false Xzibit))
  end
end

