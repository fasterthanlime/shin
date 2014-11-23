
RSpec.describe "Language", "defprotocol and deftype" do
  it "defines a simple type and plays with it" do
    expect(%Q{
           (defprotocol INoisyAnimal
             (shout [])
             (whine []))
           (deftype Dog
             INoisyAnimal
             (shout [] (print "Woof!"))
             (whine [] (print "Kai kai")))
           (let [d (Dog.)]
             (.shout d)
             (.whine d))
           }).to have_output("Woof! Kai kai")
  end
end

