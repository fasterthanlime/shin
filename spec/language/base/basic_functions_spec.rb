
RSpec.describe "Language", "basic functions" do
  it "has working inc" do
    expect(%Q{(print (inc 4))}).to have_output("5")
  end

  it "has working nil?" do
    expect(%Q{(print (nil? nil))}).to have_output("true")
    expect(%Q{(print (nil? 42))}).to  have_output("false")
  end

  it "has working truthy" do
    expect(%Q{(print (truthy true))}).to    have_output("true")
    expect(%Q{(print (truthy 42))}).to      have_output("true")
    expect(%Q{(print (truthy "hello"))}).to have_output("true")
    expect(%Q{(print (truthy false))}).to   have_output("false")
    expect(%Q{(print (truthy nil))}).to     have_output("false")
  end

  it "has working falsey" do
    expect(%Q{(print (falsey true))}).to    have_output("false")
    expect(%Q{(print (falsey 42))}).to      have_output("false")
    expect(%Q{(print (falsey "hello"))}).to have_output("false")
    expect(%Q{(print (falsey false))}).to   have_output("true")
    expect(%Q{(print (falsey nil))}).to     have_output("true")
  end

  it "has working not" do
    expect(%Q{(print (not true))}).to    have_output("false")
    expect(%Q{(print (not 42))}).to      have_output("false")
    expect(%Q{(print (not "hello"))}).to have_output("false")
    expect(%Q{(print (not false))}).to   have_output("true")
    expect(%Q{(print (not nil))}).to     have_output("true")
  end
end

