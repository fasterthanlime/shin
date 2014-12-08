(ns cljs.core
  (:require js/hamt))

;; Core protocols

(defprotocol IComparable
  (-compare [x y]))

(defprotocol INamed
  (-name [x]))

(defprotocol IEncodeJS
  (-clj->js  [x])
  (-key->js  [x]))

(defprotocol Fn) ;; marker protocol

(defprotocol IFn
  (-invoke
    ;; Yay Christmas tree!
    [_]
    [_ a]
    [_ a b]
    [_ a b c]
    [_ a b c d]
    [_ a b c d e]
    [_ a b c d e f]
    [_ a b c d e f g]
    [_ a b c d e f g h]
    [_ a b c d e f g h i]
    [_ a b c d e f g h i j]
    [_ a b c d e f g h i j k]
    [_ a b c d e f g h i j k l]
    [_ a b c d e f g h i j k l m]
    [_ a b c d e f g h i j k l m n]
    [_ a b c d e f g h i j k l m n o]
    [_ a b c d e f g h i j k l m n o p]
    [_ a b c d e f g h i j k l m n o p q]
    [_ a b c d e f g h i j k l m n o p q r]
    [_ a b c d e f g h i j k l m n o p q r s]
    [_ a b c d e f g h i j k l m n o p q r s t]
    [_ a b c d e f g h i j k l m n o p q r s t rest]))

(defprotocol ICollection
  (-conj  [rng o]))

(defprotocol IIndexed
  (-nth [coll n] [coll n not-found]))

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
  (-lookup [o k] [o k not-found]))

(defprotocol ISet
  (-disjoin [coll v]))

(defprotocol IStack
  (-peek [coll])
  (-pop [coll]))

(defprotocol IReduce
  (-reduce [coll f] [coll f start]))

(defprotocol IKVReduce
  (-kv-reduce [coll f init]))

(defprotocol IPrintable
  (-pr-str [o]))

(defprotocol IAtom)

(defprotocol IReset
  (-reset!  [o new-value]))

(defprotocol IDeref
  (-deref  [o]))

(defprotocol IMeta
  (-meta [o]))

(defprotocol IWithMeta
  (-with-meta [o meta]))

(defprotocol ISwap
  (-swap!  [o f]  [o f a]  [o f a b]  [o f a b xs]))

(defprotocol IEquiv
  (-equiv [x other]))

(defprotocol IHash
  (-hash [o]))

; mimics can't call into js, so they can't
; access hamt/hash, we have to call it for them.
; see the defn of hash later in this file.
(defprotocol IHashDelegate
  (-hash-delegate [o]))

(defprotocol IWriter
  (-write [writer s])
  (-flush [writer]))

(defprotocol IPrintWithWriter
  ; "The old IPrintable protocol's implementation consisted of building a giant
  ;  list of strings to concatenate.  This involved lots of concat calls,
  ;  intermediate vectors, and lazy-seqs, and was very slow in some older JS
  ;  engines.  IPrintWithWriter implements printing via the IWriter protocol, so it
  ;  be implemented efficiently in terms of e.g. a StringBuffer append."
  (-pr-writer [o writer opts]))

(defprotocol IWatchable
  (-notify-watches  [o oldval newval])
  (-add-watch  [o key f])
  (-remove-watch  [o key]))

;; Internal - do not use
(defn- hamt-make []
  (hamt/make {$ "hash" hash "keyEq" =}))

(defn type [x]
  (when-not (nil? x)
    (.-constructor x)))

(defn array
  []
  (.. js/Array -prototype -slice (call js-arguments)))

(defn alength
  "Returns the length of the array. Works on arrays of all types."
  [array]
  (.-length array))

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
       (recur ret (first kvs) (second kvs) (nnext kvs))
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

(defn meta
  "Returns the metadata of obj, returns nil if there is no metadata."
  [o]
  (when (and (not (nil? o))
             (satisfies? IMeta o))
    (-meta o)))

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

(defn doall
  "When lazy sequences are produced via functions that have side
  effects, any effects other than those needed to produce the first
  element in the seq do not occur until the seq is consumed. doall can
  be used to force any effects. Walks through the successive nexts of
  the seq, retains the head and returns it, thus causing the entire
  seq to reside in memory at one time."
  ([coll]
   (dorun coll)
   coll)
  ([n coll]
   (dorun n coll)
   coll))

(defn dorun
  "When lazy sequences are produced via functions that have side
  effects, any effects other than those needed to produce the first
  element in the seq do not occur until the seq is consumed. dorun can
  be used to force any effects. Walks through the successive nexts of
  the seq, does not retain the head and returns nil."
  ([coll]
   (if (seq coll)
     (recur (next coll))))
  ([n coll]
   (if (and (seq coll) (pos? n))
     (recur (dec n) (next coll)))))

(defn interleave
  "Returns a lazy seq of the first item in each coll, then the second etc."
  ([c1 c2]
     (lazy-seq
      (let [s1 (seq c1) s2 (seq c2)]
        (when (and s1 s2)
          (cons (first s1) (cons (first s2)
                                 (interleave (rest s1) (rest s2))))))))
  ([c1 c2 & colls]
     (lazy-seq
      (let [ss (map seq (conj colls c2 c1))]
        (when (every? identity ss)
          (concat (map first ss) (apply interleave (map rest ss))))))))

(defn partition
  "Returns a lazy sequence of lists of n items each, at offsets step
  apart. If step is not supplied, defaults to n, i.e. the partitions
  do not overlap. If a pad collection is supplied, use its elements as
  necessary to complete last partition upto n items. In case there are
  not enough padding elements, return a partition with less than n items."
  ([n coll]
     (partition n n coll))
  ([n step coll]
   (lazy-seq
     (let [s (seq coll)]
       (if s
         (let [p (take n s)]
           (if (== n (count p))
             (cons p (partition n step (drop step s)))
             nil))))))
  ([n step pad coll]
   (lazy-seq
     (let [s (seq coll)]
       (if s
         (let [p (take n s)]
           (if (== n (count p))
             (cons p (partition n step pad (drop step s)))
             (list (take n (concat p pad)))))
         nil)))))

(defn get-in
  "Returns the value in a nested associative structure,
  where ks is a sequence of keys. Returns nil if the key is not present,
  or the not-found value if supplied."
  ([m ks]
     (get-in m ks nil))
  ([m ks not-found]
     (loop [sentinel lookup-sentinel
            prev m
            ks (seq ks)]
       (if ks
         (if (not (satisfies? ILookup prev))
           not-found
           (let [m (get prev (first ks) sentinel)]
             (if (identical? sentinel m)
               not-found
               (recur sentinel m (next ks)))))
         prev))))

(defn assoc-in
  "Associates a value in a nested associative structure, where ks is a
  sequence of keys and v is the new value and returns a new nested structure.
  If any levels do not exist, hash-maps will be created."
  [m [k & ks] v]
  (if ks
    (assoc m k (assoc-in (get m k) ks v))
    (assoc m k v)))

(defn update-in
  "'Updates' a value in a nested associative structure, where ks is a
  sequence of keys and f is a function that will take the old value
  and any supplied args and return the new value, and returns a new
  nested structure.  If any levels do not exist, hash-maps will be
  created."
  ([m [k & ks] f]
   (if ks
     (assoc m k (update-in (get m k) ks f))
     (assoc m k (f (get m k)))))
  ([m [k & ks] f a]
   (if ks
     (assoc m k (update-in (get m k) ks f a))
     (assoc m k (f (get m k) a))))
  ([m [k & ks] f a b]
   (if ks
     (assoc m k (update-in (get m k) ks f a b))
     (assoc m k (f (get m k) a b))))
  ([m [k & ks] f a b c]
   (if ks
     (assoc m k (update-in (get m k) ks f a b c))
     (assoc m k (f (get m k) a b c))))
  ([m [k & ks] f a b c & args]
   (if ks
     (assoc m k (apply update-in (get m k) ks f a b c args))
     (assoc m k (apply f (get m k) a b c args)))))

(defn update
  "'Updates' a value in an associative structure, where k is a
  key and f is a function that will take the old value
  and any supplied args and return the new value, and returns a new
  structure.  If the key does not exist, nil is passed as the old value."
  ([m k f]
   (assoc m k (f (get m k))))
  ([m k f x]
   (assoc m k (f (get m k) x)))
  ([m k f x y]
   (assoc m k (f (get m k) x y)))
  ([m k f x y z]
   (assoc m k (f (get m k) x y z)))
  ([m k f x y z & more]
   (assoc m k (apply f (get m k) x y z more))))

(defn interpose
  "Returns a lazy seq of the elements of coll separated by sep"
  [sep coll] (drop 1 (interleave (repeat sep) coll)))

(defn filter
  "Returns a lazy sequence of the items in coll for which
  (pred item) returns true. pred must be free of side-effects."
  ([pred coll]
   (lazy-seq
     (let [s (seq coll)]
       (if s
         (let [f (first s) r (rest s)]
           (if (pred f)
             (cons f (filter pred r))
             (filter pred r))))))))

(defn- accumulating-seq-count [coll]
  (loop [s (seq coll) acc 0]
    (if (counted? s) ; assumes nil is counted, which it currently is
      (+ acc (count s))
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
  ([coll x & xs]
   (if xs
     (recur (conj coll x) (first xs) (next xs))
     (conj coll x))))

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
     (PersistentVector. nil h (+ start offset) (- end start)))))

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
   (ci-reduce cicoll f (-nth cicoll 0) 1))
  ([cicoll f val]
   (ci-reduce cicoll f val 0))
  ([cicoll f val idx]
   (let [len (-count cicoll)]
     (loop [i idx
            v val]
       (if (< i len)
         (recur (inc i) (f v (-nth cicoll i)))
         v)))))

(defn- default-compare
  [x y]
  (cond
    (*js-bop > x y) 1
    (*js-bop < x y) -1
    :else 0))

(defn compare
  [x y]
  (cond
    (identical? x y) 0

    (nil? x) -1

    (nil? y) 1

    (identical? (type x) (type y))
    (if (satisfies? IComparable x)
      (-compare x y)
      (default-compare x y))

    :else
    (throw (js/Error. "compare on non-nil objects of different types"))))

(defn- indexed-comparator [comparator]
  (fn [a b]
    (let [res (comparator (aget a 0) (aget b 0))]
      (if (== 0 res)
        (default-comparator (aget a 1) (aget b 1))
        res))))

(defn- stable-sort-array [arr comparator]
  ; .map is IE9+ :/
  (let [indexed     (.map arr (fn [el i] [$ el i]))
        icomparator (indexed-comparator comparator)
        _           (.sort indexed icomparator)
        sorted      (.map indexed (fn [el] (aget el 0)))]
    sorted))

(defn- fn->comparator
  "Given a fn that might be boolean valued or a comparator,
   return a fn that is a comparator."
  [f]
  (if (= f compare)
    compare
    (fn [x y]
      (let [r (f x y)]
        (if (number? r)
          r
          (if r
            -1
            (if (f y x) 1 0)))))))

(defn sort
  "Returns a sorted sequence of the items in coll. Comp can be
   boolean-valued comparison function, or a -/0/+ valued comparator.
   Comp defaults to compare."
  ([coll]
   (sort compare coll))
  ([comp coll]
   (if (seq coll)
     (let [a (to-array coll)]
       (seq (stable-sort-array a (fn->comparator comp))))
     ())))

(defn sort-by
  "Returns a sorted sequence of the items in coll, where the sort
   order is determined by comparing (keyfn item).  Comp can be
   boolean-valued comparison funcion, or a -/0/+ valued comparator.
   Comp defaults to compare."
  ([keyfn coll]
   (sort-by keyfn compare coll))
  ([keyfn comp coll]
     (sort (fn [x y] ((fn->comparator comp) (keyfn x) (keyfn y))) coll)))


(defn reduce
  "f should be a function of 2 arguments. If val is not supplied,
  returns the result of applying f to the first 2 items in coll, then
  applying f to that result and the 3rd item, etc. If coll contains no
  items, f must accept no arguments as well, and reduce returns the
  result of calling f with no arguments.  If coll has only 1 item, it
  is returned and f is not called.  If val is supplied, returns the
  result of applying f to val and the first item in coll, then
  applying f to that result and the 2nd item, etc. If coll contains no
  items, returns val and f is not called."
  ([f coll]
   (cond
     (satisfies? IReduce coll)
     (-reduce coll f)

     (array? coll)
     (array-reduce coll f)

     (string? coll)
     (array-reduce coll f)

     :else
     (seq-reduce f coll)))
  ([f val coll]
     (cond
       (satisfies? IReduce coll)
       (-reduce coll f val)

       (array? coll)
       (array-reduce coll f val)
      
       (string? coll)
       (array-reduce coll f val)

       :else
       (seq-reduce f val coll))))

(defn reduce-kv
  "Reduces an associative collection. f should be a function of 3
  arguments. Returns the result of applying f to init, the first key
  and the first value in coll, then applying f to that result and the
  2nd key and value, etc. If coll contains no entries, returns init
  and f is not called. Note that reduce-kv is supported on vectors,
  where the keys will be the ordinals."
  ([f init coll]
   (if (nil? coll)
     init
     (-kv-reduce coll f init))))

(defn identity [x] x)

(defn hash [o]
  (cond
    (satisfies? IHash o)
    (-hash o)

    (satisfies? IHashDelegate o)
    (hamt/hash (-hash-delegate o))

    :else
    (hamt/hash o)))

(defn get
  "Returns the value mapped to key, not-found or nil if key not present."
  ([o k]
   (cond (nil? o) nil
     (satisfies? ILookup o)
     (-lookup o k)
     
     (or (array? o) (string? o))
     (when (< k (.-length o))
       (aget o k))
     
     :else nil))
  ([o k not-found]
   (cond (nil? o) not-found
     (satisfies? ILookup o)
     (-lookup o k not-found)

     (or (array? o) (string? o))
     (if (< k (.-length o))
       (aget o k)
       not-found)
     
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
  ([coll n]
   (cond
     (not (number? n))
     (throw (js/Error. "index argument to nth must be a number"))

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
     (throw (js/Error. (str "nth not supported on this type: "
                            (pr-str coll))))))
  ([coll n not-found]
   (cond
     (not (number? n))
     (throw (js/Error. "index argument to nth must be a number"))
     
     (nil? coll)
     not-found

     (or (array? coll) (string? coll))
     (if (< n (.-length coll))
       (aget coll n)
       not-found)
     
     (satisfies? IIndexed coll)
     (-nth coll n not-found)
     
     :else
     (throw (js/Error. (str "nth not supported on this type "
                            (pr-str coll)))))))
     

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

(defn second
  "Same as (first (next x))"
  [coll]
  (first (next coll)))

(defn ffirst
  "Same as (first (first x))"
  [coll]
  (first (first coll)))

(defn nfirst
  "Same as (next (first x))"
  [coll]
  (next (first coll)))

(defn fnext
  "Same as (first (next x))"
  [coll]
  (first (next coll)))

(defn nnext
  "Same as (next (next x))"
  [coll]
  (next (next coll)))

(defn last
  "Return the last item in coll, in linear time"
  [s]
  (let [sn (next s)]
    (if (nil? sn)
      (first s)
      (recur sn))))

(defn drop
  "Returns a lazy sequence of all but the first n items in coll."
  [n coll]
  (let [step (fn [n coll]
               (let [s (seq coll)]
                 (if (and (pos? n) s)
                   (recur (dec n) (rest s))
                   s)))]
    (lazy-seq (step n coll))))

(defn take
  "Returns a lazy sequence of the first n items in coll, or all items if
  there are fewer than n."
  [n coll]
  (lazy-seq 
    (when (pos? n)
      (let [s (seq coll)]
        (when s
          (cons (first s) (take (dec n) (rest s))))))))

(defn take-while
  "Returns a lazy sequence of successive items from coll while
  (pred item) returns true. pred must be free of side-effects."
  ([pred coll]
   (lazy-seq
     (let [s (seq coll)]
       (when s
         (when (pred (first s))
           (cons (first s) (take-while pred (rest s)))))))))

(defn drop-while
  "Returns a lazy sequence of the items in coll starting from the
  first item for which (pred item) returns logical false."
  ([pred coll]
     (let [step (fn [pred coll]
                  (let [s (seq coll)]
                    (if (and s (pred (first s)))
                      (recur pred (rest s))
                      s)))]
       (lazy-seq (step pred coll)))))

(defn repeat
  "Returns a lazy (infinite!, or length n if supplied) sequence of xs."
  ([x] (lazy-seq (cons x (repeat x))))
  ([n x] (take n (repeat x))))

(defn replicate
  "Returns a lazy seq of n xs."
  [n x] (take n (repeat x)))

(defn repeatedly
  "Takes a function of no args, presumably with side effects, and
  returns an infinite (or length n if supplied) lazy sequence of calls
  to it"
  ([f] (lazy-seq (cons (f) (repeatedly f))))
  ([n f] (take n (repeatedly f))))

(deftype Range [start end step]
  Object
  (toString [coll]
    (pr-str coll))
  (equiv [coll other]
    (-equiv coll other))

  ISeqable
  (-seq [rng]
    (if (pos? step)
      (when (< start end)
        rng)
      (when (> start end)
        rng)))

  ISeq
  (-first [rng]
    (when-not (nil? (-seq rng)) start))
  (-rest [rng]
    (if-not (nil? (-seq rng))
      (Range. (+ start step) end step)
      ()))

  INext
  (-next [rng]
    (if (pos? step)
      (when (< (+ start step) end)
        (Range. (+ start step) end step))
      (when (> (+ start step) end)
        (Range. (+ start step) end step))))

  ICollection
  (-conj [rng o] (cons o rng))

  ISequential
  IEquiv
  (-equiv [rng other] (equiv-sequential rng other))

  ICounted
  (-count [rng]
    (if-not (-seq rng)
      0
      (Math/ceil (/ (- end start) step))))

  IIndexed
  (-nth [rng n]
    (if (< n (-count rng))
      (+ start (* n step))
      (if (and (> start end) (zero? step))
        start
        (throw (js/Error. "Index out of bounds")))))
  (-nth [rng n not-found]
    (if (< n (-count rng))
      (+ start (* n step))
      (if (and (> start end) (zero? step))
        start
        not-found)))

  IReduce
  (-reduce [rng f] (ci-reduce rng f))
  (-reduce [rng f init]
    (loop [i start ret init]
      (if (if (pos? step) (< i end) (> i end))
        (let [ret (f ret i)]
          (if (reduced? ret)
            @ret
            (recur (+ i step) ret)))
        ret))))

(defn range
  "Returns a lazy seq of nums from start (inclusive) to end
   (exclusive), by step, where start defaults to 0, step to 1,
   and end to infinity."
  ([] (range 0 (.-MAX_VALUE js/Number) 1))
  ([end] (range 0 end 1))
  ([start end] (range start end 1))
  ([start end step] (Range. start end step)))

(defn take-nth
  "Returns a lazy seq of every nth item in coll."
  ([n coll]
     (lazy-seq
       (when-let [s (seq coll)]
         (cons (first s) (take-nth n (drop n s)))))))

(defn seq
  "Returns a seq on the collection. If the collection is
  empty, returns nil.  (seq nil) returns nil. seq also works on
  Strings."
  [coll]
  (cond
    (nil? coll)
    nil

    (array? coll)
    (if (zero? (alength coll))
      nil
      (IndexedSeq. coll 0))
    
    (satisfies? ISeqable coll)
    (-seq coll)))

(defn name [x]
  (cond
    (satisfies? INamed x)
    (-name x)
    
    :else (throw (js/Error. "Argument to 'name' must satisfy IName"))))

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

(defn every?
  "Returns true if (pred x) is logical true for every x in coll, else
  false."
  [pred coll]
  (cond
   (nil? (seq coll)) true
   (pred (first coll)) (recur pred (next coll))
   :else false))

(defn not-every?
  "Returns false if (pred x) is logical true for every x in
  coll, else true."
  [pred coll] (not (every? pred coll)))

(defn some
  "Returns the first logical true value of (pred x) for any x in coll,
  else nil.  One common idiom is to use a set as pred, for example
  this will return :fred if :fred is in the sequence, otherwise nil:
  (some #{:fred} coll)"
  [pred coll]
    (if (seq coll)
      (if (pred (first coll))
        true
        (recur pred (next coll)))
      false))

(defn not-any?
  "Returns false if (pred x) is logical true for any x in coll,
  else true."
  [pred coll] (not (some pred coll)))

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
  (*js-uop ! (.apply = null js-arguments)))

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
  (let [args js-arguments
        len (.-length args)]
    (loop [res 0
           i 0]
      (if (< i len)
        (recur (*js-bop + res (aget args i)) (inc i))
        res))))

(defn - []
  (let [args js-arguments
        len (.-length args)]
    (loop [res (aget args 0)
           i 1]
      (if (< i len)
        (recur (*js-bop - res (aget args i)) (inc i))
        res))))

(defn * []
  (let [args js-arguments
        len (.-length args)]
    (loop [res 1
           i 0]
      (if (< i len)
        (recur (*js-bop * res (aget args i)) (inc i))
        res))))

(defn / []
  (let [args js-arguments
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
  (if (nil? obj)
    false
    (== true (aget obj (.-protocol-name protocol)))))

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

(defn prn []
  (.apply (.-log console) console js-arguments))

(defn apply
  ([f args]
   (.apply f f (into-array args)))
  ([f x args]
   (let [arglist (list* x args)]
     (.apply f f (to-array arglist))))
  ([f x y args]
   (let [arglist (list* x y args)]
     (.apply f f (to-array arglist))))
  ([f x y z args]
   (let [arglist (list* x y z args)]
     (.apply f f (to-array arglist))))
  ([f a b c d & args]
   (let [arglist (cons a (cons b (cons c (cons d (spread args)))))]
     (.apply f f (to-array arglist)))))

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

(def fresh-sym-seed 0)
(defn builtin-fresh-sym []
  (set! fresh-sym-seed (inc fresh-sym-seed))
  fresh-sym-seed)

(defn gensym [stem]
  (let [stem (if stem stem "G__")]
    (let [f (builtin-fresh-sym)]
      (symbol (str stem f)))))

;; Keyword

(defprotocol IKeyword) ; Marker protocol for mimics

(deftype Keyword [_name]
  IKeyword

  INamed
  (-name [_] _name)

  IPrintable
  (-pr-str [_]
    (str ":" _name))

  IEncodeJS
  (-clj->js [_]
    _name)

  IEquiv
  (-equiv [_ other]
    (cond
      (keyword? other)
      (= (name _) (name other))
      :else false))
  
  IFn
  (-invoke [kw coll]
    (get coll kw))
  (-invoke [kw coll not-found]
    (get coll kw not-found))
  
  IHash
  (-hash [sym]
    (hamt/hash _name)))

(defn keyword [x]
  (Keyword. x))

(defn keyword? [x]
  (satisfies? IKeyword x))

;; Symbol

(defprotocol ISymbol) ; Marker protocol for mimics

(deftype Symbol [_name _meta]
  ISymbol

  INamed
  (-name [_] _name)

  IPrintable
  (-pr-str [_]
    _name)

  IEncodeJS
  (-clj->js [_]
    _name)

  IEquiv
  (-equiv [_ other]
    (cond
      (symbol? other)
      (= (name _) (name other))
      :else false))
  
  IFn
  (-invoke [sym coll]
    (get coll sym))
  (-invoke [sym coll not-found]
    (get coll sym not-found))
  
  IHash
  (-hash [sym]
    (hamt/hash _name))
  
  IMeta
  (-meta [sym] _meta)
  
  IWithMeta
  (-with-meta [sym new-meta] (Symbol. _name new-meta)))

(defn symbol [x]
  (Symbol. x nil))

(defn symbol? [x]
  (satisfies? ISymbol x))

;; LazySeq

(deftype LazySeq [fn s]
  Object
  (sval [coll]
    (if (nil? fn)
      s
      (do
        (set! s (fn))
        (set! fn nil)
        s)))

  ISeq
  (-first [coll]
    (-seq coll)
    (when-not (nil? s)
      (first s)))
  (-rest [coll]
    (-seq coll)
    (if-not (nil? s)
      (rest s)
      ()))
  
  INext
  (-next [coll]
    (-seq coll)
    (when-not (nil? s)
      (next s)))
  
  ICollection
  (-conj [coll o] (cons o coll))
  
  ISequential
  IEquiv
  (-equiv [coll other] (equiv-sequential coll other))
  
  ISeqable
  (-seq [coll]
    (.sval coll)
    (when-not (nil? s)
      (loop [ls s]
        (if (instance? LazySeq ls)
          (recur (.sval ls))
          (do (set! s ls)
              (seq s))))))
  
  IReduce
  (-reduce [coll f] (seq-reduce f coll))
  (-reduce [coll f start] (seq-reduce f start coll))

  IPrintable
  (-pr-str [coll]
    (-seq coll)
    (if (nil? s)
      "()"
      (-pr-str s))))

;; Unquote
;; Internal - do not use

(defprotocol IUnquote) ;; marker protocol for macro expansion

(deftype Unquote [meta inner splice]
  IUnquote

  IPrintable
  (-pr-str [_]
    (let [r (if splice "~@" "~")]
      (str r (pr-str inner))))
  
  IMeta
  (-meta [_] meta)
  
  IWithMeta
  (-with-meta [_ new-meta] (Unquote. new-meta inner splice)))

(defn --unquote [inner splice]
  (Unquote. nil inner splice))

;; Quoted-regexp
;; Internal - do not use

(deftype QuotedRegexp [meta inner]
  IPrintable
  (-pr-str [_]
    (str "#" (pr-str inner)))
  
  IMeta
  (-meta [_] meta)
  
  IWithMeta
  (-with-meta [_ new-meta] (QuotedRegexp. new-meta inner)))

(defn --quoted-re [inner]
  (QuotedRegexp. nil inner))

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
    (set!  (.-watches self)  (dissoc watches key)))
  
  IMeta
  (-meta [_] meta)
  
  IWithMeta
  (-with-meta [_ meta] (Atom. state meta validator watches)))

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

(defn swap!
  "Atomically swaps the value of atom to be:
  (apply f current-value-of-atom args). Note that f may be called
  multiple times, and thus should be free of side effects.  Returns
  the value that was swapped in."
  ([a f]
     (if (instance? Atom a)
       (reset! a (f (.-state a)))
       (-swap! a f)))
  ([a f x]
     (if (instance? Atom a)
       (reset! a (f (.-state a) x))
       (-swap! a f x)))
  ([a f x y]
     (if (instance? Atom a)
       (reset! a (f (.-state a) x y))
       (-swap! a f x y)))
  ([a f x y & more]
     (if (instance? Atom a)
       (reset! a (apply f (.-state a) x y more))
       (-swap! a f x y more))))

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
   (loop [sb (str x)
          more ys]
     (if more
       (recur (*js-bop + sb (str (first more))) (next more))
       sb))))

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
   (if (= l r)
     (if more
       (recur r (first more) (next more))
       true)
     false)))

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
  (or
    (*js-bop == "[object Function]"
             (.call (.-toString (.-prototype js/Object)) f))
    (satisfies? Fn f)))

(deftype MetaFn [afn meta]
  IMeta
  (-meta [_] meta)
  IWithMeta
  (-with-meta [_ new-meta]
    (MetaFn. afn new-meta))
  Fn
  IFn
  (-invoke [_]
    (afn))
  (-invoke [_ a]
    (afn a))
  (-invoke [_ a b]
    (afn a b))
  (-invoke [_ a b c]
    (afn a b c))
  (-invoke [_ a b c d]
    (afn a b c d))
  (-invoke [_ a b c d e]
    (afn a b c d e))
  (-invoke [_ a b c d e f]
    (afn a b c d e f))
  (-invoke [_ a b c d e f g]
    (afn a b c d e f g))
  (-invoke [_ a b c d e f g h]
    (afn a b c d e f g h))
  (-invoke [_ a b c d e f g h i]
    (afn a b c d e f g h i))
  (-invoke [_ a b c d e f g h i j]
    (afn a b c d e f g h i j))
  (-invoke [_ a b c d e f g h i j k]
    (afn a b c d e f g h i j k))
  (-invoke [_ a b c d e f g h i j k l]
    (afn a b c d e f g h i j k l))
  (-invoke [_ a b c d e f g h i j k l m]
    (afn a b c d e f g h i j k l m))
  (-invoke [_ a b c d e f g h i j k l m n]
    (afn a b c d e f g h i j k l m n))
  (-invoke [_ a b c d e f g h i j k l m n o]
    (afn a b c d e f g h i j k l m n o))
  (-invoke [_ a b c d e f g h i j k l m n o p]
    (afn a b c d e f g h i j k l m n o p))
  (-invoke [_ a b c d e f g h i j k l m n o p q]
    (afn a b c d e f g h i j k l m n o p q))
  (-invoke [_ a b c d e f g h i j k l m n o p q r]
    (afn a b c d e f g h i j k l m n o p q r))
  (-invoke [_ a b c d e f g h i j k l m n o p q r s]
    (afn a b c d e f g h i j k l m n o p q r s))
  (-invoke [_ a b c d e f g h i j k l m n o p q r s t]
    (afn a b c d e f g h i j k l m n o p q r s t))
  (-invoke [_ a b c d e f g h i j k l m n o p q r s t rest]
    (apply afn a b c d e f g h i j k l m n o p q r s t rest)))

(defn with-meta
  "Returns an object of the same type and value as obj, with
  map m as its metadata."
  [o meta]
  (if (and (fn? o) (not (satisfies? IWithMeta o)))
    (MetaFn. o meta)
    (when-not (nil? o)
      (-with-meta o meta))))

(defn meta
  "Returns the metadata of obj, returns nil if there is no metadata."
  [o]
  (when (and (not (nil? o))
             (satisfies? IMeta o))
    (-meta o)))

(defn seqable? [coll]
  (satisfies? ISeqable coll))

(defn ifn? [f]
  (or (fn? f) (satisfies? IFn f)))

(defn reversible? [coll]
  (satisfies? IReversible coll))

(defn rseq [coll]
  (-rseq coll))

(defn reverse
  "Returns a seq of the items in coll in reverse order. Not lazy."
  [coll]
  (if (reversible? coll)
    (rseq coll)
    (reduce conj () coll)))

(defn list [& xs]
  (let [arr (if (*js-bop && (instance? IndexedSeq xs) (zero? (.-i xs)))
              (.-arr xs)
              (let [arr (array)]
                (loop [xs xs]
                  (if (nil? xs)
                    arr
                    (do
                      (.push arr (-first xs))
                      (recur (-next xs)))))))]
    (loop [i (alength arr) r ()]
      (if (> i 0)
        (recur (dec i) (-conj r (aget arr (dec i))))
        r))))

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

(defn- array-reduce
  ([arr f]
     (let [cnt (alength arr)]
       (if (zero? (alength arr))
         (f)
         (loop [val (aget arr 0), n 1]
           (if (< n cnt)
             (let [nval (f val (aget arr n))]
               (if (reduced? nval)
                 @nval
                 (recur nval (inc n))))
             val)))))
  ([arr f val]
     (let [cnt (alength arr)]
       (loop [val val, n 0]
         (if (< n cnt)
           (let [nval (f val (aget arr n))]
             (if (reduced? nval)
               @nval
               (recur nval (inc n))))
           val))))
  ([arr f val idx]
     (let [cnt (alength arr)]
       (loop [val val, n idx]
         (if (< n cnt)
           (let [nval (f val (aget arr n))]
             (recur nval (inc n)))
           val)))))

(defn counted? [coll]
  "Returns true if coll implements count in constant time"
  (*js-bop || (nil? coll) (satisfies? ICounted coll)))

(defn indexed? [coll]
  "Returns true if coll implements nth in constant time"
  (satisfies? IIndexed coll))

;; IndexedSeq

(deftype IndexedSeq [arr i]
  Object
  (toString [coll]
   (pr-str coll))
  (equiv [coll other]
    (-equiv coll other))

  ISeqable
  (-seq [coll] coll)

  ASeq
  ISeq
  (-first [_] (aget arr i))
  (-rest [_] (if (< (inc i) (alength arr))
               (IndexedSeq. arr (inc i))
               (list)))

  INext
  (-next [_] (if (< (inc i) (alength arr))
               (IndexedSeq. arr (inc i))
               nil))

  ICounted
  (-count [_] (- (alength arr) i))

  IIndexed
  (-nth [coll n]
    (let [i (+ n i)]
      (if (< i (alength arr))
        (aget arr i)
        nil)))
  (-nth [coll n not-found]
    (let [i (+ n i)]
      (if (< i (alength arr))
        (aget arr i)
        not-found)))

  ISequential
  IEquiv
  (-equiv [coll other] (equiv-sequential coll other))

  ICollection
  (-conj [coll o] (cons o coll))

  IReduce
  (-reduce [coll f]
    (array-reduce arr f (aget arr i) (inc i)))
  (-reduce [coll f start]
    (array-reduce arr f start i))
  
  IPrintable
  (-pr-str [coll] (seq-pr-str coll "(" ")"))
  
  IEncodeJS
  (-clj->js [coll] (.map (into-array coll) clj->js)))

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

(defn seq? [coll]
  (satisfies? ISeq coll))

;; Cons

(deftype Cons [meta first rest]
  IList
  
  ASeq
  ISeq
  (-first [coll] first)
  (-rest [coll] (if (nil? rest) () rest))
  
  INext
  (-next [coll]
    (if (nil? rest) nil (seq rest)))
  
  ICollection
  (-conj [coll o] (Cons. meta o coll))
  
  ISequential
  IEquiv
  (-equiv [coll other] (equiv-sequential coll other))
  
  ISeqable
  (-seq [coll] coll)
  
  IReduce
  (-reduce [coll f] (seq-reduce f coll))
  (-reduce [coll f start] (seq-reduce f start coll))
  
  IPrintable
  (-pr-str [coll] (seq-pr-str coll "(" ")"))
  
  IEncodeJS
  (-clj->js [coll] (.map (into-array coll) clj->js))
  
  IMeta
  (-meta [coll] meta)
  
  IWithMeta
  (-with-meta [coll meta] (Cons. meta first rest)))

(defn cons
  "Returns a new seq where x is the first element and seq is the rest."
  [x coll]
  (if (or (nil? coll)
          (satisfies? ISeq coll))
    (Cons. nil x coll)
    (Cons. nil x (seq coll))))


;; List

(deftype List [meta first rest count]
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
  (-peek [coll] first)
  (-pop [coll] (-rest coll))

  ICollection
  (-conj [coll o] (List. meta o coll (inc count)))

  ISequential
  IEquiv
  (-equiv [coll other] (equiv-sequential coll other))

  ISeqable
  (-seq [coll] coll)

  ICounted
  (-count [coll] count)

  IReduce
  (-reduce [coll f] (seq-reduce f coll))
  (-reduce [coll f start] (seq-reduce f start coll))

  IPrintable
  (-pr-str [coll] (seq-pr-str coll "(" ")"))

  IEncodeJS
  (-clj->js [coll] (.map (into-array coll) clj->js))
  
  IMeta
  (-meta [coll] meta)
  
  IWithMeta
  (-with-meta [coll meta] (List. meta first rest count)))

(deftype EmptyList [meta]
  IList

  ISeq
  (-first [coll] nil)
  (-rest [coll] ())

  INext
  (-next [coll] nil)

  IStack
  (-peek [coll] nil)
  (-pop [coll] (throw (js/Error. "Can't pop empty list")))

  ICollection
  (-conj [coll o] (List. meta o nil 1))

  ISequential
  IEquiv
  (-equiv [coll other] (equiv-sequential coll other))

  IHash
  (-hash [coll] 0)

  ISeqable
  (-seq [coll] nil)

  ICounted
  (-count [coll] 0)

  IReduce
  (-reduce [coll f] (seq-reduce f coll))
  (-reduce [coll f start] (seq-reduce f start coll))
  
  IPrintable
  (-pr-str [coll] "()")
  
  IMeta
  (-meta [coll] meta)
  
  IWithMeta
  (-with-meta [coll meta] (EmptyList. meta)))

(set! (.-EMPTY List) (EmptyList. nil nil))

(defn list? [coll]
  (satisfies? IList coll))

(defn spread
  [arglist]
  (cond
   (nil? arglist) nil
   (nil? (next arglist)) (seq (first arglist))
   :else (cons (first arglist)
               (spread (next arglist)))))

(defn concat
  "Returns a lazy seq representing the concatenation of the elements in the supplied colls."
  ([] (lazy-seq nil))
  ([x] (lazy-seq x))
  ([x y]
    (lazy-seq
      (let [s (seq x)]
        (if s
          (cons (first s) (concat (rest s) y))
          y))))
  ([x y & zs]
     (let [cat (fn cat [xys zs]
                 (lazy-seq
                   (let [xys (seq xys)]
                     (if xys
                       (cons (first xys) (cat (rest xys) zs))
                       (when zs
                         (cat (first zs) (next zs)))))))]
       (cat (concat x y) zs))))

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

(deftype PersistentVector [meta h offset cnt]
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
    (PersistentVector. meta (hamt/set (+ offset cnt) o h) offset (inc cnt)))

  ISequential
  IEquiv
  (-equiv [coll other]
    (cond
      (and (satisfies? ICounted other) (satisfies? IIndexed other))
      (equiv-ci coll other)
      
      (satisfies? ISeqable other)
      (equiv-sequential (seq coll) (seq other))
      
      :else
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
  (-nth [coll n]
    (hamt/get (+ offset n) h))
  (-nth [coll n not-found]
    (hamt/tryGet not-found (+ offset n) h))

  ILookup
  (-lookup [coll k]
    (if (number? k)
      (-nth coll k)
      nil))
  (-lookup [coll k not-found]
    (if (number? k)
      (-nth coll k not-found)
      not-found))

  IAssociative
  (-assoc [coll k v]
    (if (number? k)
      (-assoc-n coll k v)
      (throw "Vector's key for assoc must be a number.")))

  IVector
  (-assoc-n [coll n val]
    (let [i (+ offset n)
          new-h (hamt/set i val h)]
      (PersistentVector. meta new-h offset cnt)))

  IReduce
  (-reduce [coll f] (ci-reduce coll f))
  (-reduce [coll f start] (ci-reduce coll f start))

  IKVReduce
  (-kv-reduce [coll f init]
    (let [len (-count coll)]
      (loop [i 0
             v init]
        (if (< i len)
          (recur (inc i) (f v i (-nth coll i)))
          v))))

  IFn
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
  (-clj->js [coll] (.map (into-array coll) clj->js))

  IMeta
  (-meta [coll] meta)

  IWithMeta
  (-with-meta [coll meta] (PersistentVector. meta h offset cnt)))

(defn vector? [coll]
  (satisfies? IVector coll))

(defn vector []
  (let [args js-arguments
        len (.-length args)
        f (fn [h]
            (loop [i 0]
              (if (< i len)
                (do 
                  (hamt/set i (aget args i) h)
                  (recur (inc i))))))
        h (hamt/mutate f (hamt-make))]
    (PersistentVector. nil h 0 len)))

(defn vec [coll]
  (cond
    (array? coll)
    (.apply vector nil coll)
    
    (seqable? coll)
    (apply vector (seq coll))
    
    :else
    (throw "vec called on incompatible type")))

;; Map

(deftype PersistentArrayMap [h _meta]
  ICollection
  (-conj [coll entry]
    (cond
      (vector? entry)
      (PersistentArrayMap. (hamt/set (-nth entry 0) (-nth entry 1) h) _meta)
      
      (instance? PersistentArrayMap entry)
      (let [pairs (hamt/pairs (.-h entry))
            len (alength pairs)]
        (loop [i 0
               h h]
          (if (< i len)
            (let [pair (aget pairs i)
                  k (aget pair 0)
                  v (aget pair 1)]
              (recur (inc i) (hamt/set k v h)))
            (PersistentArrayMap. h _meta))))
      
      :else
      (throw (js/Error. "-conj on a map: stub"))))

  IEquiv
  (-equiv [coll other]
    (if (and (satisfies? ILookup other)
             (satisfies? ICounted other)
             (== (count coll) (count other)))
      (let [pairs (hamt/pairs h)
            len   (alength pairs)]
          (loop [i 0]
            (if (< i len)
              (let [pair (aget pairs i)
                    k    (aget pair 0)
                    v1   (aget pair 1)
                    v2   (-lookup other k)]
                (if (= v1 v2)
                  (recur (inc i))
                  false))
              true)))
      false))

  ISeqable
  (-seq [coll]
    (let [len (hamt/count h)]
      (if (== 0 len)
        nil
        (let [pairs (hamt/pairs h)]
          (loop [i 0
                 res nil]
            (if (< i len)
              (let [pair (aget pairs i)
                    k    (aget pair 0)
                    v    (aget pair 1)]
                (recur (inc i) (cons [k v] res)))
              res))))))

  ICounted
  (-count [coll] (hamt/count h))

  ILookup
  (-lookup [coll k]
    (hamt/get k h))
  (-lookup [coll k not-found]
    (hamt/tryGet not-found k h))

  IAssociative
  (-assoc [coll k v]
    (PersistentArrayMap. (hamt/set k v h) _meta))

  IMap
  (-dissoc [coll k]
    (PersistentArrayMap. (hamt/remove k h) _meta))

  IFn
  (-invoke [coll k]
    (-lookup coll k))

  IReduce
  (-reduce [coll f start]
    (throw "-reduce on a map: stub"))

  IKVReduce
  (-kv-reduce [coll f init]
    (let [pairs (hamt/pairs h)
          len (alength pairs)]
      (loop [i    0
             prev init]
        (if (< i len)
          (let [pair (aget pairs i)
                k    (aget pair 0)
                v    (aget pair 1)]
            (recur (inc i) (f prev k v)))
          prev))))
  
  IPrintable
  (-pr-str [coll]
    (let [pairs (hamt/pairs h)
          len (alength pairs)]
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
          len (alength pairs)
          r {$}]
      (loop [i 0]
        (if (< i len)
          (let [s (if (zero? i) "" " ")
                pair (aget pairs i)
                k    (aget pair 0)
                v    (aget pair 1)]
            (aset r (clj->js k) (clj->js v))
            (recur (inc i)))
          r))))

  IMeta
  (-meta [coll] _meta)

  IWithMeta
  (-with-meta [coll new-meta] (PersistentArrayMap. h new-meta)))

(defn map?
  "Return true if x satisfies IMap"
  [x]
  (if (nil? x)
    false
    (satisfies? IMap x)))

(defn hash-map []
  (let [args js-arguments
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
      (PersistentArrayMap. h nil))))

(defn merge
  "Returns a map that consists of the rest of the maps conj-ed onto
  the first.  If a key occurs in more than one map, the mapping from
  the latter (left-to-right) will be the mapping in the result."
  [& maps]
  (when (some identity maps)
    (reduce #(conj (if %1 %1 {}) %2) maps)))

;; Set

(deftype PersistentHashSet [h]
  ICollection
  (-conj [coll entry]
    (cond 
      (instance? PersistentHashSet entry)
      (let [keys (hamt/keys (.-h entry))
            len (alength keys)]
        (loop [i 0
               h h]
          (if (< i len)
            (let [k (aget keys i)]
              (recur (inc i) (hamt/set k true h)))
            (PersistentHashSet. h))))

      :else
      (let [h (hamt/set entry true h)]
        (PersistentHashSet. h))))
  
  IEquiv
  (-equiv [coll other]
    (if (and (instance? PersistentHashSet other)
             (== (count coll) (count other)))
      (let [keys (hamt/keys h)
            len   (alength keys)]
        (loop [i 0]
          (if (< i len)
            (let [k (aget keys i)]
              (if (== true (hamt/get k (.-h other)))
                (recur (inc i))
                false))
            true)))
      false))

  ISeqable
  (-seq [coll]
    (let [len (hamt/count h)]
      (if (== 0 len)
        nil
        (let [keys (hamt/keys h)]
          (loop [i 0
                 res nil]
            (if (< i len)
              (let [k (aget keys i)]
                (recur (inc i) (cons k res)))
              res))))))
  
  ICounted
  (-count [coll] (hamt/count h))
  
  ILookup
  (-lookup [coll k]
    (and (hamt/has k h) k))
  (-lookup [coll k not-found]
    (if (hamt/has k h) k not-found))
  
  IFn
  (-invoke [coll k]
    (-lookup coll k))
  
  IPrintable
  (-pr-str [coll]
    (let [keys (hamt/keys h)
          len (alength keys)]
      (loop [i 0
             r "#{"]
        (if (< i len)
          (let [s (if (zero? i) "" " ")
                k    (aget keys i)]
            (recur
              (inc i)
              (str r s (pr-str k))))
          (str r "}"))))))

; FIXME - allow non-array colls
(defn set
  "Returns a set of the distinct elements of coll."
  [coll]
  (apply hash-set coll))

(defn hash-set
  [& keys]
  (let [len (count keys)]
    (let [f (fn [h]
              (loop [i 0]
                (if (< i len)
                  (do
                    (hamt/set (nth keys i) true h)
                    (recur (inc i))))))
          h (hamt/mutate f (hamt-make))]
      (PersistentHashSet. h))))

(defn set? [coll]
  (satisfies? ISet coll))

(defn --serialize
  [coll]
  (let [acc [$]]
    (cond
      (nil? coll)
      (.push acc 74)

      (.-shinastsentinel coll)
      (do
        (.push acc 0)
        (.push acc coll))

      (vector? coll)
      (do
        (.push acc 1)
        (let [len (-count coll)]
          (loop [i 0]
            (if (< i len)
              (do
                (.push acc (--serialize (-nth coll i)))
                (recur (*js-bop + 1 i)))))))

      (seqable? coll)
      (do
        (.push acc 2)
        (loop [xs (seq coll)]
          (if xs
            (do
              (.push acc (--serialize (-first xs)))
              (recur (-next xs))))))

      (map? coll) ;; 3
      (throw (js/Error. "Serialize map: stub!"))

      (symbol? coll)
      (do
        (.push acc 4)
        (.push acc (.-_name coll)))

      (keyword? coll)
      (do
        (.push acc 5)
        (.push acc (.-_name coll)))

      (satisfies? IUnquote coll)
      (do
        (.push acc (if (.-splice coll) 7 6))
        (.push acc (--serialize (.-inner coll))))

      :else
      (do
        (.push acc 8)
        (.push acc coll)))
    acc))

(defn --serialize-macro
  [f args]
  (--serialize (.apply f nil args)))

