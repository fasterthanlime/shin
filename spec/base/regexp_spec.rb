
RSpec.describe "Language", "regexp" do
  it "has working re-find (without re-matcher)" do
    expect(%Q{
           (print (= "A" (re-find #"[A-Z]" "A")))
           (print (= "F" (re-find #"[A-Z]" "123F123")))
           }).to have_output("true true")
  end

  it "has working re-find (with re-matcher)" do
    expect(%Q{
           (let [m (re-matcher #"[A-Z]" "ABC")]
             (print (re-find m) (re-find m) (re-find m)))
           }).to have_output("A B C")
    expect(%Q{
           (let [m (re-matcher #"[a-z][a-z][a-z]" "foobarbaz")]
             (print (re-find m) (re-find m) (re-find m)))
           }).to have_output("foo bar baz")
    expect(%Q{
           (let [m (re-matcher #"[A-Za-z]+" "bundle exec$rails1ARGL")]
             (print (re-find m) (re-find m) (re-find m) (re-find m)))
           }).to have_output("bundle exec rails ARGL")
    expect(%Q{
           (let [m (re-matcher #"([A-Za-z])[A-Za-z]+" "bundle exec$rails1ARGL")]
             (print (= (vector "bundle" "b") (re-find m)))
             (print (= (vector "exec"   "e") (re-find m)))
             (print (= (vector "rails"  "r") (re-find m)))
             (print (= (vector "ARGL"   "A") (re-find m))))
           }).to have_output("true true true true")
  end

  it "has working re-matches" do
    expect(%Q{
           (print (nil? (re-matches #"[A-Z]" "Awoops")))
           (print (= "A" (re-matches #"[A-Z]" "A")))
           (print (= (vector "A123" "A") (re-matches #"([A-Z]).*" "A123")))
           }).to have_output("true true true")
  end
end


