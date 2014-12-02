
RSpec.describe "Language", "binding" do
  it "works" do
    expect(%Q{
           (def foo "foo")
           (def bar "bar")
           (print foo bar)
           (binding [foo "non"
                     bar (str foo bar)]
             (print bar))
           (print foo bar)
           }).to have_output(["foo bar", "conformant", "foo bar"])
  end
end

