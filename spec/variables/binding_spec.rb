
RSpec.describe "Language", "binding" do
  it "works" do
    expect(%Q{
           (def foo "very ")
           (def bar "conformant")
           (print bar)
           (binding [foo "non"
                     bar (str foo bar)]
             (print bar))
           (print bar)
           }).to have_output(["conformant", "very conformant", "conformant"])
  end
end

