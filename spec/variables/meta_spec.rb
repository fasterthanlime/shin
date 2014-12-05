
RSpec.describe "Language", "meta" do
  describe "types supporting meta" do
    it "MetaFn" do
      expect(%Q{
           (let [f  (fn [])
                 fm (with-meta f {:key "Xzibit"})]
             (print (nil? (meta f)))
             (print (nil? (meta fm)))
             (print (:key (meta fm))))
             }).to have_output(%w(true false Xzibit))
    end

    it "PersistentVector" do
      expect(%Q{
           (let [v []
                 vm (with-meta v {:key "Xzibit"})]
             (print (nil? (meta v)))
             (print (nil? (meta vm)))
             (print (:key (meta vm))))
             }).to have_output(%w(true false Xzibit))
    end

    it "EmptyList" do
      expect(%Q{
           (let [l ()
                 lm (with-meta l {:key "Xzibit"})]
             (assert (instance? EmptyList l))
             (print (nil? (meta l)))
             (print (nil? (meta lm)))
             (print (:key (meta lm))))
             }).to have_output(%w(true false Xzibit))
    end

    it "List" do
      expect(%Q{
           (let [l (conj () 1)
                 lm (with-meta l {:key "Xzibit"})]
             (assert (instance? List l))
             (print (nil? (meta l)))
             (print (nil? (meta lm)))
             (print (:key (meta lm))))
             }).to have_output(%w(true false Xzibit))
    end

    it "Cons" do
      expect(%Q{
           (let [l (cons 1 nil)
                 lm (with-meta l {:key "Xzibit"})]
             (assert (instance? Cons l))
             (print (nil? (meta l)))
             (print (nil? (meta lm)))
             (print (:key (meta lm))))
             }).to have_output(%w(true false Xzibit))
    end

    it "Symbol" do
      expect(%Q{
           (let [l 'hello
                 lm (with-meta l {:key "Xzibit"})]
             (print (nil? (meta l)))
             (print (nil? (meta lm)))
             (print (:key (meta lm))))
             }).to have_output(%w(true false Xzibit))
    end
  end

  describe "types not supporting meta" do
    it "Keyword" do
      expect do
        expect(%Q{
           (let [l :hello
                 lm (with-meta l {:key "Xzibit"})])
               }).to have_output(%w(true false Xzibit))
      end.to raise_error V8::Error, /IWithMeta/
    end
  end
end

