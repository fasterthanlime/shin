
RSpec.describe "Language", "pr-str" do
  it "works on strings" do
    expect(%Q{(print (pr-str "Hello"))}).to have_output(%q{"Hello"})
  end

  it "works on numbers" do
    expect(%Q{(print (pr-str 42))}).to have_output(%q{42})
  end

  it "works on keywords" do
    expect(%Q{(print (pr-str :Hello))}).to have_output(%q{:Hello})
  end

  it "works on symbols" do
    expect(%Q{(print (pr-str 'Hello))}).to have_output(%q{Hello})
  end

  it "works on lists" do
    expect(%Q{(print (pr-str '(1 2 3)))}).to have_output(%q{(1 2 3)})
  end

  it "works on vectors" do
    expect(%Q{(print (pr-str [1 2 3]))}).to have_output(%q{[1 2 3]})
  end

  it "works on maps" do
    expect(%Q{(print (pr-str {:count 42}))}).to have_output(%q{{:count 42}})
  end
end

