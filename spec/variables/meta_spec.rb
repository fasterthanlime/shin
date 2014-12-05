
RSpec.describe "Language", "meta" do
  it "functions" do
    expect(%Q{
           (let [fn (fn [])
                 fm (with-meta fn {:key "Xzibit"})]
             (print (nil? (meta fn)))
             (print (nil? (meta fm)))
             (print (:key (meta fm))))
           }).to have_output(%w(true false Xzibit))
  end
end

