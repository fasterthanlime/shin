
RSpec.describe "Infrastructure", "AST equality" do
  include Shin
  include Shin::Utils::AstMaker

  describe "hash" do
    it "keyword" do
      expect(sample_kw.hash).to eql(sample_kw.hash)
    end

    it "symbol" do
      expect(sample_sym.hash).to eql(sample_sym.hash)
    end

    it "literal" do
      expect(literal(42).hash).to eql(literal(42).hash)
      expect(literal("omnomnom").hash).to eql(literal("omnomnom").hash)
    end

    it "list" do
      expect(numeric_list.hash).to eql(numeric_list.hash)
    end

    it "vector" do
      expect(numeric_vec.hash).to eql(numeric_vec.hash)
    end

    it "map" do
      expect(sample_map.hash).to eql(sample_map.hash)
    end
  end

  describe "eql?"
    it "keyword" do
      expect(sample_kw).to eql(sample_kw)
    end

    it "symbol" do
      expect(sample_sym).to eql(sample_sym)
    end

    it "literal" do
      expect(literal(42)).to eql(literal(42))
      expect(literal("omnomnom")).to eql(literal("omnomnom"))
    end

    it "list" do
      expect(numeric_list).to eql(numeric_list)
    end

    it "vector" do
      expect(numeric_vec).to eql(numeric_vec)
    end

    it "map" do
      expect(sample_map).to eql(sample_map)
    end
end



