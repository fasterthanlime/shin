
RSpec.describe "Language", "defprotocol and deftype" do
  it "defines a simple type and plays with it" do
    expect(%Q{
           (defprotocol INoisyAnimal
             (-shout [animal])
             (-whine [animal]))
           (deftype Dog
             INoisyAnimal
             (-shout [dog] (print "Woof!"))
             (-whine [dog] (print "Kai kai")))
           (let [d (Dog.)]
             (-shout d)
             (-whine d))
           }).to have_output("Woof! Kai kai")
  end
end

