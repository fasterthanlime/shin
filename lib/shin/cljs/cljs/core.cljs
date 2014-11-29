(ns cljs.core
  (:require js/hamt))

;; Internal - do not use
(defn- hamt-make []
  (hamt/make {$ "hash" hash "keyEq" =}))

(defn array
  []
  (.. js/Array -prototype -slice (call arguments)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defn to-array
  "Naive impl of to-array as a start."
  [s]
  (let [ary [$]]
    (loop [s s]
      (if (seq s)
        (do (.push ary (first s))
            (recur (next s)))
        ary))))

(defn into-array
  ([aseq]
   (into-array nil aseq))
  ([type aseq]
   (reduce (fn [a x] (.push a x) a) (array) aseq)))

;; Why is this here?

(defn assoc
  "assoc[iate]. When applied to a map, returns a new map of the
  same (hashed/sorted) type, that contains the mapping of key(s) to
  val(s). When applied to a vector, returns a new vector that
  contains val at index."
  ([coll k v]
   (if (nil? coll)
     (hash-map k v)
     (-assoc coll k v)))
  ([coll k v & kvs]
   (let [ret (assoc coll k v)]
     (if kvs
       ; TODO: use recur instead when #56 is fixed
       ; (recur ret (first kvs) (second kvs) (nnext kvs))
       (let [args (into-array kvs)]
         (.unshift args ret)
         (.apply assoc nil args)) 
       ret))))

(defn dissoc
  "dissoc[iate]. Returns a new map of the same (hashed/sorted) type,
  that does not contain a mapping for key(s)."
  ([coll] coll)
  ([coll k]
    (when-not (nil? coll)
      (-dissoc coll k)))
  ([coll k & ks]
    (if (not (nil? coll))
      (let [ret (dissoc coll k)]
        (if ks
          (let [args (into-array ks)]
            (.unshift args ret)
            (.apply dissoc nil args))
          ret)))))

(defn peek
  "For a list or queue, same as first, for a vector, same as, but much
  more efficient than, last. If the collection is empty, returns nil."
  [coll]
  (when-not (nil? coll)
    (-peek coll)))

(defn pop
  "For a list or queue, returns a new list/queue without the first
  item, for a vector, returns a new vector without the last item.
  Note - not the same as next/butlast."
  [coll]
  (when-not (nil? coll)
    (-pop coll)))

; TODO: implement properly, it's just a stub for now.
(defn doall [s]
  s)

(defn interpose
  ; FIXME lazy
  "Returns a lazy seq of the elements of coll separated by sep"
  [sep coll]
  (let [s  (seq coll)]
    (if s
      (let [x  (first s)
            xs (next s)]
        (if xs
          (cons x (cons sep (interpose sep xs)))
          (cons x nil)))
      '())))

(defn- accumulating-seq-count [coll]
  (loop [s (seq coll) acc 0]
    (if (counted? s) ; assumes nil is counted, which it currently is
      (+ acc (-count s))
      (recur (next s) (inc acc)))))

(defn count [coll]
  (cond
    (nil? coll)
    0

    (satisfies? ICounted coll)
    (-count coll)

    (or (string? coll) (array? coll))
    (.-length coll)

    :else (accumulating-seq-count coll)))

(defn complement [f]
  (fn [& args]
    (not (apply f args))))

(defn conj
  "conj[oin]. Returns a new collection with the xs
  'added'. (conj nil item) returns (item).  The 'addition' may
  happen at different 'places' depending on the concrete type."
  ([] [])
  ([coll] coll)
  ([coll x]
   (if (nil? coll)
     (list x)
     (-conj coll x)))

  ;; TODO: uncomment when #56 is fixed
  ; ([coll x & xs]
  ;  (if xs
  ;    (recur (conj coll x) (first xs) (next xs))
  ;    (conj coll x)))
  )

(defn subvec
  "Returns a persistent vector of the items in vector from
  start (inclusive) to end (exclusive).  If end is not supplied,
  defaults to (count vector). This operation is O(1) and very fast, as
  the resulting vector shares structure with the original and no
  trimming is done."
  ([v start]
   (subvec v start (count v)))
  ([v start end]
   (let [h          (.-h v)
         offset     (.-offset v)
         cnt        (.-cnt v)
         new-offset (+ start offset)
         new-cnt    (- end start)]
     (if (neg? new-cnt) (throw "subvec gave a negative size"))
     (PersistentVector. h (+ start offset) (- end start)))))

;; FIXME accept multiple colls
;; FIXME lazy
(defn map
  ([f coll]
   (let [s (seq coll)]
     (when s
       (cons (f (first s)) (map f (rest s)))))))

(defn- seq-reduce
  ([f coll]
   (let [[x & xs] coll] (reduce f x xs)))
  ([f z coll]
   (if (empty? coll)
     z
     (let [[x & xs] coll]
       (reduce f (f z x) xs)))))

(defn- seq-pr-str
  "Accepts any collection which satisfies the ISeq protocol and prints them out."
  [coll before after]
  (loop [i 0
         r before
         curr coll]
    (let [x  (first curr)
          xs (rest curr)
          s  (if (zero? i) "" " ")]
      (if (nil? x)
        (str r after)
        (recur (inc i) (str r s (pr-str x)) xs)))))

(defn- ci-pr-str
  "Accepts any collection which satisfies the ICounted and IIndexed protocols and prints them out."
  [cicoll before after]
  (let [len (-count cicoll)]
    (loop [r before
           i 0]
      (let [s (if (zero? i) "" " ")]
        (if (< i len)
          (recur (str r s (pr-str (-nth cicoll i))) (inc i))
          (str r after))))))

(defn- ci-reduce
  "Accepts any collection which satisfies the ICounted and IIndexed protocols and
reduces them without incurring seq initialization"
  ([cicoll f]
   (ci-reduce f (-nth 0 cicoll) 1))
  ([cicoll f val]
   (ci-reduce f val 0))
  ([cicoll f val idx]
   (let [len (-count cicoll)]
     (loop [i 0
            v val]
       (if (< i len)
         (recur (inc i) (f (-nth i cicoll)))
         v)))))

;; TODO: IReduce
(defn reduce
  ([f coll]
   (let [[x & xs] coll] (reduce f x xs)))
  ([f z coll]
   (if (empty? coll)
     z
     (let [[x & xs] coll]
       (reduce f (f z x) xs)))))

(defn hash [x]
  (cond
    (or (symbol? x) (keyword? x))
    (hamt/hash (name x))
    
    :else
    (hamt/hash x)))

(defn get
  ([o k]
   (get o k nil))
  ([o k not-found]
   (cond
     (satisfies? ILookup o)
     ; TODO multiple arity protocols, damn
     (let [res (-lookup o k)]
       (if res res not-found))
     
     (or (array? o) (string? o))
     (if (< k (.-length o))
       (aget o k))
     
     :else not-found)))

(defn next
  "Returns a seq of the items after the first. Calls seq on its
  argument.  If there are no more items, returns nil"
  [coll]
  (cond
    (nil? coll)
    coll
    
    (satisfies? INext coll)
    (-next coll)
    
    :else (seq (rest coll))))


(defn nthnext
  "Returns the nth next of coll, (seq coll) when n is 0."
  [coll n]
  (cond
    (= n 0)
    (seq coll)
    
    :else
    (loop [i n
           curr coll]
      (if (> i 0)
        (recur (dec i) (next curr))
        curr))))

(defn rest
  "Returns a possibly empty seq of the items after the first. Calls seq on its
  argument."
  [coll]
  (cond
    (nil? coll)
    nil
    
    (satisfies? ISeq coll)
    (-rest coll)
    
    :else
    (let [s (seq coll)]
      (if s
        (-rest s)
        ()))))

(defn next
  "Returns a seq of the items after the first. Calls seq on its
  argument.  If there are no more items, returns nil"
  [coll]
  (cond
    (nil? coll)
    nil
    
    (satisfies? INext coll)
    (-next coll)
    
    :else
    (seq (rest coll))))

; Returns the nth rest of coll, coll when n is 0.
(defn nthrest [coll n]
  (cond
    (= n 0)
    coll
    
    :else
    (loop [i n
           curr coll]
      (if (> i 0)
        (recur (dec i) (next curr))
        curr))))

(defn empty?
  "Returns true if coll has no items - same as (not (seq coll)).
  Please use the idiom (seq x) rather than (not (empty? x))"
  [coll]
  (or (nil? coll)
      (not (seq coll))))

(defn- linear-traversal-nth
  ([coll n]
   (cond
     (nil? coll)     (throw (Error. "Index out of bounds"))
     (zero? n)       (if (seq coll)
                       (first coll)
                       (throw (Error. "Index out of bounds")))
     (indexed? coll) (-nth coll n)
     (seq coll)      (recur (next coll) (dec n))
     :else           (throw (Error. "Index out of bounds"))))
  ([coll n not-found]
   (cond
     (nil? coll)     not-found
     (zero? n)       (if (seq coll)
                       (first coll)
                       not-found)
     (indexed? coll) (-nth coll n not-found)
     (seq coll)      (recur (next coll) (dec n) not-found)
     :else           not-found)))

(defn nth
  "Returns the value at the index. get returns nil if index out of
  bounds, nth throws an exception unless not-found is supplied.  nth
  also works for strings, arrays, regex Matchers and Lists, and,
  in O(n) time, for sequences."
  [coll n]
  (cond
    (not (number? n))
    (throw "index argument to nth must be a number")

    (nil? coll)
    coll
    
    (or (array? coll) (string? coll))
    (when (< n (.-length coll))
      (aget coll n))

    (satisfies? IIndexed coll)
    (-nth coll n)

    (satisfies? ISeq coll)
    (linear-traversal-nth coll n)

    :else
    (throw (str "nth not supported on this type: " (pr-str coll)))))

(defn first
  "Returns the first item in the collection. Calls seq on its
  argument. If coll is nil, returns nil."
  [coll]
  (cond
    (nil? coll)
    nil
    
    (satisfies? ISeq coll)
    (-first coll)
    
    :else
    (let [s (seq coll)]
      (if (nil? s)
        nil
        (-first s)))))

(defn last
  "Return the last item in coll, in linear time"
  [s]
  (let [sn (next s)]
    (if (nil? sn)
      (first s)
      (recur sn))))

(defn drop
  [n coll]
  (let [step (fn [n coll]
               (let [s (seq coll)]
                 (if (and (pos? n) s)
                   (recur (dec n) (rest s))
                   s)))]
    ; FIXME: lazy-seq
    (step n coll)))

; FIXME: lazy
(defn take
  [n coll]
  (when (pos? n)
    (let [s (seq coll)]
      (when s
        (cons (first s) (take (dec n) (rest s)))))))

; FIXME: lazy
(defn take-while
  ([pred coll]
   (let [s (seq coll)]
     (when s
       (when (pred (first s))
         (cons (first s) (take-while pred (rest s))))))))

; FIXME: lazy
(defn drop-while
  ([pred coll]
     (let [step (fn [pred coll]
                  (let [s (seq coll)]
                    (if (and s (pred (first s)))
                      (recur pred (rest s))
                      s)))]
       (step pred coll))))

;; TODO: implement.
(defn seq
  "Returns a seq on the collection. If the collection is
  empty, returns nil.  (seq nil) returns nil. seq also works on
  Strings."
  [coll]
  (cond
    (nil? coll)
    nil
    
    (satisfies? ISeqable coll)
    (-seq coll)))

(defn name [x]
  (.-_name x))

(defn nil? [x]
  (*js-bop || (*js-bop === nil x) (*js-bop === "undefined" (*js-uop typeof x))))

(defn truthy [x]
  (*js-uop ! (*js-bop || (*js-bop === x false) (*js-bop == x null))))

(defn falsey [x]
  (*js-uop ! (truthy x)))

(def not falsey)

(defn dec [x]
  (*js-bop - x 1))

(defn inc [x]
  (*js-bop + x 1))

(defn even? [x]
  (*js-bop == 0 (*js-bop % x 2)))

(defn odd? [x]
  (*js-bop != 0 (*js-bop % x 2)))

(defn pos? [x]
  (*js-bop > x 0))

(defn zero? [x]
  (*js-bop == x 0))

(defn neg? [x]
  (*js-bop < x 0))

(defn not= []
  (*js-uop ! (.apply = null arguments)))

(defn >
  ([x]          true)
  ([x y]        (*js-bop > x y))
  ([x y & more] (if (*js-bop > x y) (apply > (cons y more)) false)))

(defn <
  ([x]          true)
  ([x y]        (*js-bop < x y))
  ([x y & more] (if (*js-bop < x y) (apply < (cons y more)) false)))

(defn >=
  ([x]          true)
  ([x y]        (*js-bop >= x y))
  ([x y & more] (if (*js-bop >= x y) (apply >= (cons y more)) false)))

(defn <=
  ([x]          true)
  ([x y]        (*js-bop <= x y))
  ([x y & more] (if (*js-bop <= x y) (apply <= (cons y more)) false)))

(defn or
  ([x]          (truthy x))
  ([x y]        (*js-bop || (truthy x) (truthy y)))
  ([x y & more] (if (*js-bop || (truthy x) (truthy y)) true (apply or more))))

(defn and
  ([x]          (truthy x))
  ([x y]        (*js-bop && (truthy x) (truthy y)))
  ([x y & more] (if (*js-bop && (truthy x) (truthy y)) (apply and more) false)))

(defn + []
  (let [args arguments
        len (.-length args)]
    (loop [res 0
           i 0]
      (if (< i len)
        (recur (*js-bop + res (aget args i)) (inc i))
        res))))

(defn - []
  (let [args arguments
        len (.-length args)]
    (loop [res (aget args 0)
           i 1]
      (if (< i len)
        (recur (*js-bop - res (aget args i)) (inc i))
        res))))

(defn * []
  (let [args arguments
        len (.-length args)]
    (loop [res 1
           i 0]
      (if (< i len)
        (recur (*js-bop * res (aget args i)) (inc i))
        res))))

(defn / []
  (let [args arguments
        len (.-length args)]
    (loop [res (aget args 0)
           i 1]
      (if (< i len)
        (recur (*js-bop / res (aget args i)) (inc i))
        res))))

(defn mod [a b]
  (*js-bop % a b))

(defn string? [x]
  (=== "string" (*js-uop typeof x)))

(defn number? [x]
  (=== "number" (*js-uop typeof x)))

(defn boolean? [x]
  (=== "boolean" (*js-uop typeof x)))

(defn array? [x]
  (instance? Array x))

(defn satisfies? [protocol obj]
  (let [protos (.-_protocols obj)]
    (if (nil? protos)
      false
      (let [len (.-length protos)]
        (loop [i 0]
          (let [x (aget protos i)]
            (if (=== x protocol)
              true
              (if (< i len)
                (recur (inc i))
                false))))))))

(defn pr-str [x]
  (cond
    (nil? x)
    "nil"

    (string? x)
    (str "\"" x "\"") 

    (number? x)
    (str x)

    (boolean? x)
    (str x)

    (array? x)
    (let [len (.-length x)]
      (loop [r "[$"
             i 0]
        (if (< i len)
          (recur (str r " " (pr-str (aget x i))) (inc i))
          (str r "]"))))

    (satisfies? IPrintable x)
    (-pr-str x)
    
    :else
    (str x)))

(defn prn [& args]
  (.apply (.-log console) console arguments))

(defn apply [f args]
  (.apply f nil (if args (into-array args) [$])))

(def lookup-sentinel {$})
(defn contains? [coll v]
  "Returns true if key is present in the given collection, otherwise
  returns false.  Note that for numerically indexed collections like
  vectors and arrays, this tests if the numeric key is within the
  range of indexes. 'contains?' operates constant or logarithmic time;
  it will not perform a linear search for a value.  See also 'some'."
  (if (identical? (get coll v lookup-sentinel) lookup-sentinel)
    false
    true))

(defn gensym [stem]
  (let [stem (if stem stem "G__")]
    (symbol (str stem (fresh_sym)))))

;; Core protocols

(defprotocol IEncodeJS
  (-clj->js  [x])
  (-key->js  [x]))

(defprotocol IFn
  ;; FIXME: should be invoke - surely we can fix that.
  (-invoke [x]))

(defprotocol ICollection
  (-conj  [rng o]))

(defprotocol IIndexed
  ; FIXME multiple arity protocols
  (-nth [coll n]))
  ; (-nth [coll n] [coll n not-found]))

(defprotocol ISeqable
  (-seq [o]))

(defprotocol ISequential)

(defprotocol IList)

(defprotocol IReversible
  (-rseq  [coll]))

(defprotocol ISorted
  (-sorted-seq  [coll ascending?])
  (-sorted-seq-from  [coll k ascending?])
  (-entry-key  [coll entry])
  (-comparator  [coll]))

(defprotocol IVector
  (-assoc-n [coll n val]))

(defprotocol IAssociative
  (-contains-key? [coll k])
  (-assoc [coll k v]))

(defprotocol IMap
  (-dissoc [coll k]))

(defprotocol ICounted
  (-count [coll]))

(defprotocol ASeq)

(defprotocol ISeq
    (-first [coll])
    (-rest  [coll]))

(defprotocol INext
  (-next [coll]))

(defprotocol ILookup
  ;; FIXME multiple arity protocols
  (-lookup [o k])
  ; (-lookup [o k] [o k not-found])
)

(defprotocol ISet
  (-disjoin [coll v]))

(defprotocol IStack
  (-peek [coll])
  (-pop [coll]))

;; TODO: multiple dispatch for protocols
(defprotocol IReduce
  (-reduce [coll f start]))

(defprotocol IPrintable
  (-pr-str [o]))

(defprotocol IAtom)

(defprotocol IReset
  (-reset!  [o new-value]))

(defprotocol IDeref
  (-deref  [o]))

; TODO: multiple dispatch for protocols
; (defprotocol ISwap
;     (-swap!  [o f]  [o f a]  [o f a b]  [o f a b xs]))

(defprotocol ISwap
  (-swap!  [o f & xs]))

(defprotocol IEquiv
  (-equiv [x other]))

(defprotocol IWatchable
  (-notify-watches  [this oldval newval])
  (-add-watch  [this key f])
  (-remove-watch  [this key]))

;; Keyword

(deftype Keyword [_name]
  IPrintable
  (-pr-str [_]
    (str ":" _name))

  IEncodeJS
  (-clj->js [_]
    _name)

  IEquiv
  (-equiv [_ other]
    (cond
      (instance? Keyword other)
      (= (name _) (name other))
      :else false))
  
  IFn
  (-invoke [_ coll]
    (get coll _)))

(defn keyword [x]
  (Keyword. x))

(defn keyword? [x]
  (instance? Keyword x))

;; FIXME - this should be automatic, see #50
(set! (.-call (.-prototype Keyword)) (fn [_ coll] (-invoke this coll)))

;; Symbol

(deftype Symbol [_name]
  IPrintable
  (-pr-str [_]
    _name)

  IEncodeJS
  (-clj->js [_]
    _name)

  IEquiv
  (-equiv [_ other]
    (cond
      (instance? Symbol other)
      (= (name _) (name other))
      :else false))
  
  IFn
  (-invoke [_ coll]
    (get coll _)))

(defn symbol [x]
  (Symbol. x))

(defn symbol? [x]
  (instance? Symbol x))

;; FIXME - this should be automatic, see #50
(set! (.-call (.-prototype Symbol)) (fn [_ coll] (-invoke this coll)))

;; Unquote
;; Internal - do not use

(deftype Unquote [inner splice]
  IPrintable
  (-pr-str [_]
    (let [r (if splice "~@" "~")]
      (str r (pr-str inner)))))

(defn --unquote [inner splice]
  (Unquote. inner splice))

(defn unquote? [x]
  (instance? Unquote x))

;; Atom

(deftype Atom [state meta validator watches]
  IAtom
  
  IDeref
  (-deref  [_] state)
  
  IWatchable
  (-notify-watches  [self oldval newval]
    ;; TODO rewrite with doseq when #34 is in.
    (loop [pairs (.apply list nil (hamt/pairs (.-h watches)))]
      (when-not (empty? pairs)
        (let [[key f] (first pairs)]
          (f key self oldval newval)
          (recur (next pairs))))))
  (-add-watch  [self key f]
    (set!  (.-watches self)  (assoc watches key f))
    self)
  (-remove-watch  [self key]
    (set!  (.-watches self)  (dissoc watches key))))

(defn atom [val]
  (Atom. val nil nil nil))

;; generic to all refs
(defn deref
  [o]
  (-deref o))

(defn reset!
  "Sets the value of atom to newval without regard for the
  current value. Returns newval."
  [a new-value]
  (if  (instance? Atom a)
    (let  [validate  (.-validator a)]
      (when-not  (nil? validate)
        (assert  (validate new-value)  "Validator rejected reference state"))
      (let  [old-value  (.-state a)]
        (set!  (.-state a) new-value)
        (when-not  (nil?  (.-watches a))
          (-notify-watches a old-value new-value))
        new-value))
    (-reset! a new-value)))

(defn swap! [atom f & args]
  (reset! atom (apply f (cons @atom args))))

(defn add-watch [atom key f]
  (-add-watch atom key f))

(defn remove-watch [atom key]
  (-remove-watch atom key))

;; Conversions

(defn js->clj [x]
  (cond
    (nil? x)
    nil

    (string? x)
    x

    (number? x)
    x

    (boolean? x)
    x
    
    (array? x)
    (.apply vector nil x)
    
    :else
    (let [els [$]]
      (.forEach (.keys Object x) (fn [key]
                                   (.push els key)
                                   (.push els (aget x key))))
      (.apply hash-map nil els))))

(defn clj->js [x]
  (cond
    (nil? x)
    nil
    
    (string? x)
    x
    
    (number? x)
    x
    
    (boolean? x)
    x
    
    (satisfies? IEncodeJS x)
    (-clj->js x)
    
    :else x))

(defn str
  "With no args, returns the empty string. With one arg x, returns
  x.toString().  (str nil) returns the empty string. With more than
  one arg, returns the concatenation of the str values of the args."
  ([] "")
  ([x] (if (nil? x)
         ""
         (String. x)))
  ([x & ys]
   ;; TODO: recur version?
   (*js-bop + (str x) (apply str ys))))

(defn subs
  "Returns the substring of s beginning at start inclusive, and ending
  at end (defaults to length of string), exclusive."
  ([s start] (.substring s start))
  ([s start end] (.substring s start end)))

(defn identical? [x y]
  "Tests if 2 arguments are the same object"
  (=== x y))

(defn == [x y]
  (*js-bop == x y))

(defn === [x y]
  (*js-bop === x y))

(defn =
  ([l r]
   (cond
     (*js-bop === l r)
     true
     
     (or (nil? l) (nil? r))
     false

     (satisfies? IEquiv l)
     (-equiv l r)
     
     :else false))
  
  ([l r & more]
   (and (= l r) (apply = (cons r more)))))

;; Regexp

(deftype Matcher [pattern haystack index])

(defn re-matches [pattern haystack]
  (let [matches (.match haystack pattern)]
    (cond
      (nil? matches)
      nil
      
      (= 1 (.-length matches))
      (let [m (aget matches 0)]
        ;; Clojure says: full match or nothing.
        (if (== (.-length m) (.-length haystack))
          m
          nil))
      
      :else
      (let [m (aget matches 0)]
        ;; Ditto
        (if (== (.-length m) (.-length haystack))
          (vec matches) 
          nil)))))

(defn re-matcher [pattern haystack]
  (Matcher. pattern haystack 0))

(defn re-find [pattern haystack]
  (let [matches
    (cond
      (instance? Matcher pattern)
      (let [matcher  pattern
            pattern  (.-pattern matcher)
            haystack (.-haystack matcher)
            index    (.-index matcher)
            substack (.substring haystack index)
            matches  (.exec pattern substack)]
        (if (not (nil? matches))
          (let [first-match (aget matches 0)
                len   (.-length first-match)
                index (.-index  matches)]
            (set! (.-index matcher) (+ (.-index matcher) index len))))
        matches)
      
      :else
      (.exec pattern haystack))]
    (cond
      (nil? matches)
      nil
      
      (= 1 (.-length matches))
      (aget matches 0)
      
      :else (vec matches))))

;; preds

(defn boolean [x]
  (if x true false))

(defn fn? [f]
  (instance? Function f))

(defn ifn? [f]
  (or (fn? f) (satisfies? IFn f)))

(defn seqable? [coll]
  (satisfies? ISeqable coll))

(defn reversible? [coll]
  (satisfies? IReversible coll))

(defn coll? [coll]
  (satisfies? ICollection coll))

(defn associative? [coll]
  (satisfies? IAssociative coll))

(defn sequential? [coll]
  (satisfies? ISequential coll))

(defn sorted? [coll]
  "Returns true if coll satisfies ISorted"
  (satisfies? ISorted coll))

(defn reduceable? [coll]
  "Returns true if coll satisfies IReduce"
  (satisfies? IReduce coll))

(defn counted? [coll]
  "Returns true if coll implements count in constant time"
  (satisfies? ICounted coll))

(defn indexed? [coll]
  "Returns true if coll implements nth in constant time"
  (satisfies? IIndexed coll))

(defn- equiv-ci
  "Accepts any collection which satisfies the ICounted and IIndexed protocols and compares them"
  [x y]
  (boolean
    (let [len (-count x)]
      (when (== len (-count y))
        (loop [i 0]
          (if (< i len)
            (let [l (-nth x i)
                  r (-nth y i)]
              (if (= l r)
                (recur (inc i))
                false))
            true))))))

(defn- equiv-sequential
  "Assumes x is sequential. Returns true if x equals y, otherwise
  returns false."
  [x y]
  (boolean
    (when (sequential? y)
      (if (and (counted? x) (counted? y)
               (not (== (count x) (count y))))
        false
        (loop [xs (seq x) ys (seq y)]
          (cond
            (nil? xs)
            (nil? ys)
            
            (= (first xs) (first ys))
            (recur (next xs) (next ys))
            
            :else false))))))

;; Seq

(deftype LazySeq)

(defn seq? [coll]
  (satisfies? ISeq coll))

;; Cons

(deftype Cons [first rest]
  IList
  
  ASeq
  ISeq
  (-first [coll] first)
  (-rest [coll] (if (nil? rest) () rest))
  
  INext
  (-next [coll]
    (if (nil? rest) nil (seq rest)))
  
  ICollection
  (-conj [coll o] (Cons. o coll))
  
  ISequential
  IEquiv
  (-equiv [coll other] (equiv-sequential coll other))
  
  ISeqable
  (-seq [coll] coll)
  
  IReduce
  ; TODO: multiple arity protocols
  (-reduce [coll f start] (seq-reduce f start coll))
  
  IPrintable
  (-pr-str [coll] (seq-pr-str coll "(" ")"))
  
  IEncodeJS
  (-clj->js [coll] (.map (into-array coll) clj->js)))

(defn cons
  "Returns a new seq where x is the first element and seq is the rest."
  [x coll]
  (if (or (nil? coll)
          (satisfies? ISeq coll))
    (Cons. x coll)
    (Cons. x (seq coll))))


;; List

(deftype List [first rest count]
  IList

  ASeq
  ISeq
  (-first [coll] first)
  (-rest [coll]
    (if (== count 1)
      ()
      rest))

  INext
  (-next [coll]
    (if (== count 1)
      nil
      rest))

  IStack
  (-peek [coll]
    (if (== count 0) nil first))
  (-pop [coll]
    (if (== count 0)
      (throw (js/Error "Can't pop empty list"))
      (-rest coll)))

  ICollection
  (-conj [coll o] (List. o coll (inc count)))

  ISequential
  IEquiv
  (-equiv [coll other] (equiv-sequential coll other))

  ; TODO: EmptyList
  ISeqable
  (-seq [coll]
    (if (== 0 count) nil coll))

  ICounted
  (-count [coll] count)

  IReduce
  ; FIXME: multiple arity dispatch in protocols
  ;(-reduce [coll f] (seq-reduce f coll))
  (-reduce [coll f start] (seq-reduce f start coll))

  IPrintable
  (-pr-str [coll] (seq-pr-str coll "(" ")"))

  IEncodeJS
  (-clj->js [coll] (.map (into-array coll) clj->js)))

; TODO: deftype EmptyList

(set! List/EMPTY (List. nil nil 0))

(defn list? [coll]
  (satisfies? IList coll))

(defn list []
  (let [args arguments
        len (.-length args)]
    (if (= 0 len)
      (.-EMPTY List)
      (let [car  (aget args 0)
            cdr (if (> len 1) (.apply list nil (.call (.-slice (.-prototype Array)) args 1)) nil)]
        (List. car cdr len)))))

(defn spread
  [arglist]
  (cond
   (nil? arglist) nil
   (nil? (next arglist)) (seq (first arglist))
   :else (cons (first arglist)
               (spread (next arglist)))))

(defn list*
  "Creates a new list containing the items prepended to the rest, the
  last of which will be treated as a sequence."
  ([args] (seq args))
  ([a args] (cons a args))
  ([a b args] (cons a (cons b args)))
  ([a b c args] (cons a (cons b (cons c args))))
  ([a b c d & more]
     (cons a (cons b (cons c (cons d (spread more)))))))

;; Vector

(deftype PersistentVector [h offset cnt]
  IStack
  (-peek [coll]
    (when (> cnt 0)
      (-nth coll (dec cnt))))
  (-pop [coll]
    (cond
      (zero? cnt) (throw (js/Error. "Can't pop empty vector"))
      (== 1 cnt) []
      :else  (subvec coll 0 (dec cnt))))


  ICollection
  (-conj [coll o]
    (PersistentVector. (hamt/set (+ offset cnt) o h) offset (inc cnt)))

  ISequential
  IEquiv
  (-equiv [coll other]
    (if (and (satisfies? ICounted other) (satisfies? IIndexed other))
      (equiv-ci coll other)
      false))

  ICounted
  (-count [coll] cnt)

  ISeqable
  ; TODO: better impl
  (-seq [coll]
    (if (== 0 cnt)
      nil
      (let [r [$]]
        (loop [i 0]
          (if (< i cnt)
            (do
              (.push r (-nth coll i))
              (recur (inc i)))))
        (.apply list nil r))))

  IIndexed
  ; TODO: multiple arity protocols
  ; TODO: check bounds
  (-nth [coll n]
    (hamt/get (+ offset n) h))

  ILookup
  ; TODO: multiple arity protocols
  (-lookup [coll k] (if (number? k)
                      (-nth coll k)
                      nil))

  IAssociative
  (-assoc [coll k v]
    (if (number? k)
      (-assoc-n coll k v)
      (throw "Vector's key for assoc must be a number.")))

  IVector
  (-assoc-n [coll n val]
    (let [i (+ offset n)
          new-h (hamt/set i val h)]
      (PersistentVector. new-h offset cnt)))

  IReduce
  ;; TODO: multiple dispatch for protocols
  (-reduce [coll f start]
    (ci-reduce coll f start))

  ;; TODO: IKVReduce, etc.

  IFn
  ;; TODO: multiple arity protocols
  (-invoke [coll k]
    (-nth coll k))

  IReversible
  (-rseq [coll]
    ; (if (pos? cnt)
    ;   (RSeq. coll (dec cnt) nil))
    (throw "PersistentVector/-rseq stub"))

  IPrintable
  (-pr-str [coll] (ci-pr-str coll "[" "]"))
  
  IEncodeJS
  (-clj->js [coll] (.map (into-array coll) clj->js)))

;; FIXME - this should be automatic, see #50
(set! (.-call (.-prototype PersistentVector)) (fn [_ coll] (-invoke this coll)))

(defn vector? [coll]
  (satisfies? IVector coll))

(defn vector []
  (let [args arguments
        len (.-length args)
        f (fn [h]
            (loop [i 0]
              (if (< i len)
                (do 
                  (hamt/set i (aget args i) h)
                  (recur (inc i))))))
        h (hamt/mutate f (hamt-make))]
    (PersistentVector. h 0 len)))

(defn vec [coll]
  (cond
    (array? coll)
    (.apply vector nil coll)
    
    (seqable? coll)
    (apply vector (seq coll))
    
    :else
    (throw "vec called on incompatible type")))

;; Map

(deftype PersistentArrayMap [h]
  ICollection
  (-conj [coll entry]
    (if (vector? entry)
      (PersistentArrayMap. (-assoc (-nth entry 0) (-nth entry 1)))
      (throw "-conj on a map: stub")))

  IEquiv
  (-equiv [coll other]
    (if (and (satisfies? ILookup other)
             (satisfies? ICounted other)
             (== (count coll) (count other)))
      (let [pairs (hamt/pairs h)
              len   (.-length pairs)]
          (loop [i 0]
            (if (< i len)
              (let [pair (aget pairs i)
                    k    (aget pair 0)
                    v    (aget pair 1)]
                (if (= v (-lookup other k))
                  (recur (inc i))
                  false)))
            true))
      false))

  ISeqable
  (-seq [coll]
    (throw "-seq on a map: stub"))

  ICounted
  (-count [coll] (hamt/count h))

  ILookup
  ; TODO: multiple arity protocols
  (-lookup [coll k]
    (hamt/get k h))

  IAssociative
  (-assoc [coll k v]
    (PersistentArrayMap. (hamt/set k v h)))

  IMap
  (-dissoc [coll k v]
    (PersistentArrayMap. (hamt/remove k h)))

  IFn
  ; TODO multiple arity protocols
  (-invoke [coll k]
    (-lookup coll k))

  ;; TODO: IKVReduce

  IReduce
  (-reduce [coll f start]
    (throw "-reduce on a map: stub"))
  
  IPrintable
  (-pr-str [coll]
    (let [pairs (hamt/pairs h)
          len (.-length pairs)]
      (loop [i 0
             r "{"]
        (if (< i len)
          (let [s (if (zero? i) "" " ")
                pair (aget pairs i)
                k    (aget pair 0)
                v    (aget pair 1)]
            (recur
              (inc i)
              (str r s (pr-str k) " " (pr-str v))))
          (str r "}")))))
  
  IEncodeJS
  (-clj->js [coll]
    (let [pairs (hamt/pairs h)
          len (.-length pairs)
          r {$}]
      (loop [i 0]
        (if (< i len)
          (let [s (if (zero? i) "" " ")
                pair (aget pairs i)
                k    (aget pair 0)
                v    (aget pair 1)]
            (aset r (clj->js k) (clj->js v))
            (recur (inc i)))
          r)))))

(set! (.-call (.-prototype PersistentArrayMap)) (fn [_ k] (-invoke this k)))

(defn map?
  "Return true if x satisfies IMap"
  [x]
  (if (nil? x)
    false
    (satisfies? IMap x)))

(defn hash-map []
  (let [args arguments
        len (.-length args)
        pairlen (/ len 2)]
    (if (not= 0 (mod len 2))
      (throw "Odd number of elements passed to hash-map"))
    (let [f (fn [h]
              (loop [i 0]
                (if (< i pairlen)
                  (do
                    (hamt/set (aget args (* 2 i)) (aget args (+ 1 (* 2 i))) h)
                    (recur (inc i))))))
          h (hamt/mutate f (hamt-make))]
      (PersistentArrayMap. h))))

;; Set

(deftype PersistentSet)

; FIXME - allow non-array colls
(defn set
  "Returns a set of the distinct elements of coll."
  [coll]
  (apply hash-set coll))

(defn hash-set
  [& keys]
  (let [len (count keys)
        res [$]]
    (loop [i 0]
      (if (< i len)
        (do
          (.push res (nth keys i))
          (.push res true)
          (recur (inc i)))
        (.apply hash-map nil res)))))

(defn set? [coll]
  (satisfies? ISet coll))

