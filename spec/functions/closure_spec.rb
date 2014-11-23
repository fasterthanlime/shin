
RSpec.describe "Language", "closure" do
  it "no-argument closures" do
    expect(%Q{ (#(print "Hello")) }).to have_output("Hello")
  end

  it "closures with % and %%" do
    expect(%Q{ (#(print % %%) "Hello" "World") }).to have_output("Hello World")
  end

  it "closures with %1 and %4" do
    expect(%Q{
              (#(print %1 %4) "Hello" "Sometimes" "Trying" "World")
           }).to have_output("Hello World")
  end

  it "raises error when nested closures" do
    expect do
      expect(%Q{ (#(print #(str "Hello world"))) }).to have_output("Hello")
    end.to raise_error(Shin::SyntaxError)
  end
end

