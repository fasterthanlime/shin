
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

    it "PersistentArrayMap" do
      expect(%Q{
           (let [m {}
                 mm (with-meta m {:key "Xzibit"})]
             (print (nil? (meta m)))
             (print (nil? (meta mm)))
             (print (:key (meta mm))))
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
           (let [c (cons 1 nil)
                 cm (with-meta c {:key "Xzibit"})]
             (assert (instance? Cons c))
             (print (nil? (meta c)))
             (print (nil? (meta cm)))
             (print (:key (meta cm))))
             }).to have_output(%w(true false Xzibit))
    end

    it "Symbol" do
      expect(%Q{
           (let [s 'hello
                 sm (with-meta s {:key "Xzibit"})]
             (print (nil? (meta s)))
             (print (nil? (meta sm)))
             (print (:key (meta sm))))
             }).to have_output(%w(true false Xzibit))
    end

    it "Atom" do
      expect(%Q{
           (let [a (atom nil)
                 am (with-meta a {:key "Xzibit"})]
             (print (nil? (meta a)))
             (print (nil? (meta am)))
             (print (:key (meta am))))
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

  describe "shin-only types supporting meta" do
    it "Unquote" do
      expect(%Q{
           (let [u (--unquote nil false)
                 um (with-meta u {:key "Xzibit"})]
             (print (nil? (meta u)))
             (print (nil? (meta um)))
             (print (:key (meta um))))
             }).to have_output(%w(true false Xzibit))
    end

    it "QuotedRegexp" do
      expect(%Q{
           (let [r (--quoted-re nil false)
                 rm (with-meta r {:key "Xzibit"})]
             (print (nil? (meta r)))
             (print (nil? (meta rm)))
             (print (:key (meta rm))))
             }).to have_output(%w(true false Xzibit))
    end
  end
end

