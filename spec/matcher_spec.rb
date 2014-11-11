
require 'shin/utils/matcher'
include Shin::Utils::Matcher

RSpec.describe "Matcher", "matches?" do
  it "matches any identifier via keyword" do
    ast_match %Q{defn}, ":id"
  end
  it "matches any keyword via keyword" do
    ast_match %Q{:keys}, ":kw"
  end
  it "matches any number via keyword" do
    ast_match %Q{42}, ":num"
  end
  it "matches any string via keyword" do
    ast_match %Q{"Hello world."}, ":str"
  end
  it "matches any map via keyword" do
    ast_match %Q{{:a "hello" 3 []}}, ":map"
  end
  it "matches any list via keyword" do
    ast_match %Q{(one two three)}, ":list"
  end
  it "matches any vector via keyword" do
    ast_match %Q{[nothing else "matters"]}, ":vec"
  end

  it "matches verbatim identifiers" do
    ast_match %Q{defn}, "defn"
  end
  it "matches verbatim strings" do
    ast_match %Q{"hello"}, %Q{"hello"}
  end
  it "matches verbatim numbers" do
    ast_match %Q{42}, "42"
  end

  it "matches any list by example" do
    ast_match %Q{(1 2 3)}, "()"
  end
  it "matches any vector by example" do
    ast_match %Q{[1 2 3]}, "[]"
  end
  it "matches any map by example" do
    ast_match %Q{{:a "a" :b "b"}}, "{}"
  end

  it "raises on invalid types by keyword" do
    expect { ast_match %Q{:a}, ":nonsense" }.to raise_error
  end
  it "raises on invalid S-expr pattern" do
    expect { ast_match %Q{:a}, "(abacus" }.to raise_error
  end
  it "raises on invalid S-expr pattern" do
    expect { ast_match %Q{:a}, "(abacus" }.to raise_error
  end

  it "rejects unmatched strings" do
    ast_no_match %Q{42}, ":str"
    ast_no_match %Q{42}, %Q{"hello"}
    ast_no_match %Q{"bye"}, %Q{"hello"}
  end

  it "rejects unmatched seqs" do
    %w(:list :vec :map).each do |type|
      ast_no_match %Q{42}, type
    end
  end

  it "rejects seqs with unmatched innards" do
    ast_no_match %Q{[42]}, %Q{[:str]}
    ast_no_match %Q{(defn)}, %Q{(:num)}
    ast_no_match %Q{{:a "Hello"}}, %Q{{:kw :kw}}
  end
end

private

def ast_match(code, pattern, positive = true)
  expect(matches?(Shin::Parser.parse(code), pattern)).to be(positive)
end

def ast_no_match(code, pattern)
  ast_match(code, pattern, false)
end

