
require 'shin/utils/hamster'

RSpec.describe "Infrastructure", "Utils::Hamster" do

  before(:example) do
    @utils = Object.new
    @utils.extend(Shin::Utils::Hamster)
  end

  describe "walk_deque" do
    it "walks deque from back to front" do
      res = []
      deq = Hamster.deque(1, 2, 3, 4)
      @utils.walk_deque(deq) do |el|
        res << el
      end
      expect(res).to eq([1, 2, 3, 4])
    end
  end

end


