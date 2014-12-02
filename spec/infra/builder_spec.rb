
RSpec.describe "Infrastructure", "JstBuilder" do

  describe "with_scope" do
    it "looks up into single scope" do
      builder = Shin::JstBuilder.new
      scope = Shin::Scope.new
      scope['deadbeef'] = '0xdeadbeef'
      called = false
      builder.with_scope(scope) do
        called = true
        expect(builder.lookup('deadbeef')).to eq('0xdeadbeef')
      end
      expect(called).to be_truthy
    end

    it "looks up into nested scopes, in order" do
      builder = Shin::JstBuilder.new
      scope1 = Shin::Scope.new
      scope1['deadbeef'] = 'uh oh.'
      scope1['livemeat'] = '0xnothexad'
      scope2 = Shin::Scope.new
      scope2['deadbeef'] = '0xdeadbeef'

      called1 = false
      called2 = false
      builder.with_scope(scope1) do
        called1 = true
        builder.with_scope(scope2) do
          called2 = true
          expect(builder.lookup('deadbeef')).to eq('0xdeadbeef')
          expect(builder.lookup('livemeat')).to eq('0xnothexad')
        end
      end
      expect(called1).to be_truthy
      expect(called2).to be_truthy
    end
  end

  describe "into" do
    it "creates vase as needed" do
      sentinel = Shin::JST::Literal.new(nil)

      recipient = []
      expect(recipient).to receive(:<<).with(sentinel)

      builder = Shin::JstBuilder.new
      builder.into(recipient, :expression) do
        builder << sentinel
      end
    end
  end

end

