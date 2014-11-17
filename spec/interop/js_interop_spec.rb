
RSpec.describe "Language", "js interop" do
  describe "JS literals" do
    it "can make arrays" do
      expect(%Q{
            (def band [$ "eenie" "meenie" "moe"])
            (print (aget band 0) (aget band 1) (aget band 2))
            }).to have_output("eenie meenie moe")
    end

    it "can make objects" do
      expect(%Q{
            (def dude {$ "name" "buddy holly"
                          "job"  "singer"})
            (print (aget dude "name") (aget dude "job"))
             }).to have_output("buddy holly singer")
    end
  end

  describe "aget" do
    it "works on arrays" do
      expect(%Q{
            (def band [$ "eenie" "meenie" "moe"])
            (print (aget band 0) (aget band 1) (aget band 2))
            }).to have_output("eenie meenie moe")
    end

    it "works on objects" do
      expect(%Q{
            (def dude {$ "name" "buddy holly"
                          "job"  "singer"})
            (print (aget dude "name"))
            }).to have_output("buddy holly")
    end
  end

  describe "aset" do
    it "works on arrays" do
      expect(%Q{
            (def band [$ "eenie" "woops" "moe"])
            (aset band 1 "meenie")
            (print (aget band 0) (aget band 1) (aget band 2))
            }).to have_output("eenie meenie moe")
    end

    it "works on objects" do
      expect(%Q{
            (def dude {$ "name" "buddy holly"
                          "job"  "deceased"})
            (aset dude "job" "singer")
            (print (aget dude "name") (aget dude "job"))
             }).to have_output("buddy holly singer")
    end
  end
end



