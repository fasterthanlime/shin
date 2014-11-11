
RSpec.describe "Matcher", "matches?" do
  it "matches any identifier via keyword" do
    expect(%Q{defn}).to ast_match(":id")
  end
  it "matches any keyword via keyword" do
    expect(%Q{:keys}).to ast_match(":kw")
  end
  it "matches any number via keyword" do
    expect(%Q{42}).to ast_match(":num")
  end
  it "matches any string via keyword" do
    expect(%Q{"Hello world."}).to ast_match(":str")
  end
  it "matches any map via keyword" do
    expect(%Q{{:a "hello" 3 []}}).to ast_match(":map")
  end
  it "matches any list via keyword" do
    expect(%Q{(one two three)}).to ast_match(":list")
  end
  it "matches any vector via keyword" do
    expect(%Q{[nothing else "matters"]}).to ast_match(":vec")
  end

  it "matches verbatim identifiers" do
    expect(%Q{defn}).to ast_match("defn")
  end
  it "matches verbatim strings" do
    expect(%Q{"hello"}).to ast_match(%Q{"hello"})
  end
  it "matches verbatim numbers" do
    expect(%Q{42}).to ast_match("42")
  end

  it "matches any list by example" do
    expect(%Q{(1 2 3)}).to ast_match("()")
  end
  it "matches any vector by example" do
    expect(%Q{[1 2 3]}).to ast_match("[]")
  end
  it "matches any map by example" do
    expect(%Q{{:a "a" :b "b"}}).to ast_match("{}")
  end

  it "raises on invalid types by keyword" do
    expect { Shin::Utils::Matcher.send(:matches?, Shin::AST::Keyword.new(nil, ""), ":nonsense") }.to raise_error
  end
  it "raises on invalid S-expr pattern" do
    expect { Shin::Utils::Matcher.send(:matches?, Shin::AST::Keyword.new(nil, ""), "(unclosed") }.to raise_error
  end

  it "applies the star operator correctly" do
    expect(%Q{()}).to ast_match("(:str*)")
    expect(%Q{("a")}).to ast_match("(:str*)")
    expect(%Q{("a" "b")}).to ast_match("(:str*)")
  end

  it "applies the plus operator correctly" do
    expect(%Q{()}).to_not ast_match("(:str+)")
    expect(%Q{("a")}).to ast_match("(:str+)")
    expect(%Q{("a" "b")}).to ast_match("(:str+)")
  end

  it "applies the question mark operator correctly" do
    expect(%Q{()}).to ast_match("(:str?)")
    expect(%Q{("a")}).to ast_match("(:str?)")
    expect(%Q{("a" "b")}).to_not ast_match("(:str?)")
  end

  it "rejects unmatched strings" do
    expect(%Q{42}).to_not ast_match(":str")
    expect(%Q{42}).to_not ast_match(%Q{"hello"})
    expect(%Q{"bye"}).to_not ast_match(%Q{"hello"})
  end

  it "rejects unmatched seqs" do
    %w(:list :vec :map).each do |type|
      expect(%Q{42}).to_not ast_match(type)
    end
  end

  it "rejects seqs with unmatched innards" do
    expect(%Q{[42]}).to_not ast_match(%Q{[:str]})
    expect(%Q{(defn)}).to_not ast_match(%Q{(:num)})
    expect(%Q{{:a "Hello"}}).to_not ast_match(%Q{{:kw :kw}})
  end
end

