(ns shin.core
  (:require js/hamt
            js/shin))

(def init shin/init)

(defn ->array [vec]
  (let [r [$]
        len (count vec)]
    (loop [i 0]
      (if (< i len)
        (do 
          (.push r (get vec i))
          (recur (inc i)))
        r))))

(defn assoc [coll & kvs]
  (if (odd? (count kvs))
    (throw "Odd number of kvs to assoc")
    (if (nil? coll)
      (apply hash-map kvs)
      (.apply (.-assoc coll) coll (->array kvs)))))
(set! shin/assoc assoc)

(defn dissoc [coll & kvs]
  (.apply (.-dissoc coll) coll (->array kvs)))
(set! shin/dissoc dissoc)

(defn count [coll]
  (if (nil? coll)
    0
    (cond
      (satisfies? ICounted coll)
      (-count coll)

      (array? coll)
      (.-length coll)
      
      (string? coll)
      (.-length coll)
      
      ;; TODO we can count lots of things...
      :else
      0)))
(set! shin/count count)

(defn complement [f]
  (fn [& args]
    (not (apply f args))))
(set! shin/complement complement)

;; FIXME probably not right
(defn conj [coll x] (.conj coll x))

;; FIXME probably not right
(defn cons [x coll] (.cons coll x))

(defn subvec [coll start end]
  (.subvec coll start end))

;; FIXME accept multiple colls
;; FIXME lazy
(defn map [f coll]
  (.map coll f))

(defn hash [x]
  (cond
    (or (symbol? x) (keyword? x))
    (.hash hamt (name x))
    
    :else
    (.hash hamt x)))
(set! shin/hash hash)

(def list? shin/list?)
(def seq? shin/seq?)
(def vector? shin/vector?)
(def map? shin/map?)
(def set? shin/set?)
(def collection? shin/collection?)
(def sequential? shin/sequential?)
(def associative? shin/associative?)
(def counted? shin/counted?)
(def indexed? shin/indexed?)
(def reduceable? shin/reduceable?)
(def seqable? shin/seqable?)
(def reversible? shin/reversible?)

(def re-matches shin/re-matches)
(def re-matcher shin/re-matcher)
(def re-find shin/re-find)

(def PersistentVector shin/PersistentVector)
(def PersistentArrayMap shin/PersistentArrayMap)
(def PersistentList shin/PersistentList)

(defn vector []
  (let [args arguments]
    (PersistentVector.
      (fn [h]
        (loop [i 0]
          (if (< i (.-length args))
            (do 
              (.set hamt i (aget args i) h)
              (recur (inc i)))))))))
(set! shin/vector vector) ;; dat workaround.

(defn set [args]
  (let [len (.-length args)
        res [$]]
    (loop [i 0]
      (if (< i len)
        (do
          (.push res (aget args i))
          (.push res true)
          (recur (inc i)))
        (.apply hash-map nil res)))))
(set! shin/set set)

(defn hash-map []
  (let [args arguments
        len (.-length args)
        pairlen (/ len 2)]
    (if (not= 0 (mod len 2))
      (throw "Odd number of elements passed to hash-map"))
    (PersistentArrayMap.
      (fn [h]
        (loop [i 0]
          (if (< i pairlen)
            (do
              (.set hamt (aget args (* i 2)) (aget args (+ 1 (* i 2))) h)
              (recur (inc i)))))))))
(set! shin/hash-map hash-map)

(defn list []
  (let [args arguments
        len (.-length args)]
    (if (= 0 len)
      (.-EMPTY PersistentList)
      (let [car  (aget args 0)
            cdr (if (> len 1) (.apply list nil (.call (.-slice (.-prototype Array)) args 1)) nil)]
        (PersistentList. car cdr)))))
(set! shin/list list)

(defn get
  ([coll key]
   (get coll key nil))
  ([coll key not-found]
   (let [r (.get coll key)]
     (if (nil? r) not-found r))))
(set! shin/get get)

; Returns a seq of the items after the first. Calls seq on its
; argument. If there are no more items, returns nil
(defn next [coll]
  (.next coll))
(set! shin/next next)

; Returns the nth next of coll, (seq coll) when n is 0.
(defn nthnext [coll n]
  (cond
    (= n 0)
    (seq coll)
    
    :else
    (loop [i n
           curr coll]
      (if (> i 0)
        (recur (dec i) (next curr))
        curr))))

; Returns a possibly empty seq of the items after the first. Calls seq
; on its argument.
(defn rest [coll]
  (drop 1 (seq coll)))
(set! shin/rest rest)

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

(defn empty? [coll]
  (.is_empty coll))
(set! shin/empty? empty?)

(defn nth [coll n]
  (.nth coll n))
(set! shin/nth nth)

(defn last [coll]
  (.last coll))
(set! shin/last last)

(defn first [coll]
  (.first coll))
(set! shin/first first)

; FIXME: lazy
(defn drop [n coll]
  (.drop coll n))
(set! shin/drop drop)

; FIXME: lazy
(defn take [n coll]
  (.take coll n))
(set! shin/take take)

; FIXME: lazy
(defn take-while [n coll]
  (.take_while coll n))
(set! shin/take-while take-while)

; FIXME: lazy
(defn drop-while [n coll]
  (.drop_while coll n))
(set! shin/drop-while drop-while)

;; TODO: implement.
; Returns a seq on the collection. If the collection is
; empty, returns nil.  (seq nil) returns nil. seq also works
; on Strings, native Java arrays (of reference types) and any
; objects that implement Iterable.
(defn seq [coll]
  coll)
(set! shin/seq seq)

(defn vec [coll]
  (if (not (instance? Array coll))
    (throw "vecs of non-arrays: stub"))
  (.apply vector nil coll))
(set! shin/vec vec)

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
  (*js-bop === "string" (*js-uop typeof x)))

(defn number? [x]
  (*js-bop === "number" (*js-uop typeof x)))

(defn boolean? [x]
  (*js-bop === "boolean" (*js-uop typeof x)))

(defn array? [x]
  (instance? Array x))

(defn satisfies? [protocol obj]
  (let [protos (.-_protocols obj)]
    (if (nil? protos)
      false
      (let [len (.-length protos)]
        (loop [i 0]
          (let [x (aget protos i)]
            (if (*js-bop === x protocol)
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
(set! shin/pr-str pr-str)

(defn prn [& args]
  (.apply (.-log console) console arguments))

(defn apply [f args]
  (.apply f nil (->array args)))

(defn contains? [coll key]
  (not (nil? (get coll key))))

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

(defprotocol ICounted
  (-count [coll]))

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

;; FIXME - this should be automatic
(set! (.-call (.-prototype Keyword)) (fn [_ coll] (-invoke this coll)))
(set! shin/Keyword Keyword)
(set! shin/keyword keyword)
(set! shin/keyword? keyword?)

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

;; FIXME - this should be automatic
(set! (.-call (.-prototype Symbol)) (fn [_ coll] (-invoke this coll)))
(set! shin/Symbol Symbol)
(set! shin/symbol symbol)
(set! shin/symbol? symbol?)

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

;; FIXME - this should be automatic
(set! shin/Unquote Unquote)
(set! shin/--unquote --unquote)
(set! shin/unquote? unquote?)

;; Atom

(deftype Atom [state meta validator watches]
  IAtom
  
  IDeref
  (-deref  [_] state)
  
  IWatchable
  (-notify-watches  [self oldval newval]
    ; (doseq  [[key f] watches]
    ;   (f key self oldval newval)))
    ;; TODO rewrite when #34 is in.
    (loop [pairs (.pairs watches)]
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
(set! shin/js->clj js->clj)

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
(set! shin/clj->js clj->js)

(defn str []
  (let [args arguments
        len (.-length args)
        r [$]]
    (loop [i 0]
      (let [arg (aget args i)]
        (if (< i len)
          (do
            (.push r (cond
                       (nil? arg)
                       "<nil>"

                       (.-toString arg)
                       (.toString arg)

                       :else
                       arg))
            (recur (inc i)))
          (.apply (.-concat (.-prototype String)) "" r))))))
(set! shin/str str)

(defn identical? [x y]
  "Tests if 2 arguments are the same object"
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
(set! shin/= =)

(defn reduce
  ([f coll]
   (let [[x & xs] coll] (reduce f x xs)))
  ([f z coll]
   (if (empty? coll)
     z
     (let [[x & xs] coll]
       (reduce f (f z x) xs)))))
(set! shin/reduce reduce)

;; Regexp

(deftype Matcher [pattern haystack index])

(defn re-matches [pattern haystack]
  (let [matches (.match haystack (RegExp. (str "^" (.-source pattern) "$")))]
    (cond
      (nil? matches)
      nil
      
      (= 1 (.-length matches))
      (aget matches 0)
      
      :else
      (vec matches))))

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

;; Tack on prototypes to stuff.
(let [printers [$
                PersistentVector
                PersistentArrayMap
                PersistentList]]
  (.forEach printers (fn [x]
                       (.push (.-_protocols (.-prototype x)) IPrintable))))

(let [counters [$ 
                PersistentVector
                PersistentList ; eeh that's not really true, it's not O(1)
                ]]
  (.forEach counters (fn [x]
                       (.push (.-_protocols (.-prototype x)) ICounted))))

(let [encoders [$ 
                PersistentVector
                PersistentArrayMap
                PersistentList
                ]]
  (.forEach encoders (fn [x]
                       (.push (.-_protocols (.-prototype x)) IEncodeJS))))

(let [equivalents [$ 
                PersistentVector
                PersistentArrayMap
                PersistentList
                ]]
  (.forEach equivalents (fn [x]
                       (.push (.-_protocols (.-prototype x)) IEquiv))))

