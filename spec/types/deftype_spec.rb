
RSpec.describe "Language", "defprotocol and deftype" do
  it "defines a simple type and plays with it" do
    expect(%Q{
           (defprotocol INoisyAnimal
             (-shout [animal]))
           (deftype Dog
             INoisyAnimal
             (-shout [dog] (print "Woof!")))
           (deftype Cat
             INoisyAnimal
             (-shout [cat] (print "Meow!")))
           (let [d (Dog.)
                 c (Cat.)]
             (-shout d)
             (-shout c))
           }).to have_output("Woof! Meow!")
  end

  it "defines a simple type with fields and plays with it" do
    expect(%Q{
           (defprotocol INoisyAnimal
             (-shout [animal]))
           (deftype Dog [name]
            INoisyAnimal
            (-shout [dog]
              (let [name  (str "Sir " name)]
                (print (str name ": Woof!")))))
           (-shout (Dog. "Fido"))
           }).to have_output("Sir Fido: Woof!")
  end

  it "defines a simple type with mutable fields" do
    expect(%Q{
           (defprotocol INoisyAnimal
             (-shout [_]))
           (defprotocol IRename
             (-rename [_ name]))
           (deftype Dog [^:mutable name]
            IRename
            (-rename [_ new-name]
              (set! name new-name))
            INoisyAnimal
            (-shout [_]
              (let [name  (str "Sir " name)]
                (print (str name ": Woof!")))))
           (let [d (Dog. "Fido")]
             (-shout d)
             (-rename d "Rufus")
             (-shout d))
           }).to have_output("Sir Fido: Woof! Sir Rufus: Woof!")
  end

  it "defines a protocol with multiple arity functions" do
    expect(%Q{
           (defprotocol ITestProtocol
             (-test [x] [x y] [x y & ys]))
           (deftype Tester []
            ITestProtocol
            (-test [x]
              (print "Arity 1"))
            (-test [x y]
              (print "Arity 2"))
            (-test [x y & ys]
              (print "Arity variadic")))
           (let [d (Tester.)]
             (-test d)
             (-test d 1)
             (-test d 1 2 3))
           }).to have_output(['Arity 1', 'Arity 2', 'Arity variadic'])
  end
end

