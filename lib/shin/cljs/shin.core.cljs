(ns shin.core
  (:require js/hamt
            js/shin))

(def init shin/init)

;; Internal - do not use
(def --unquote shin/--unquote)

(def vec shin/vec)
(def hash-map shin/hash-map)
(def set shin/set)
(def list shin/list)
(def get shin/get)
(def empty? shin/empty?)
(def nth shin/nth)
(def nthnext shin/nthnext)
(def seq shin/seq)
(def assoc shin/assoc)
(def dissoc shin/dissoc)

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

(def last shin/last)
(def cons shin/cons)
(def conj shin/conj)
(def first shin/first)
(def drop shin/drop)
(def take shin/take)
(def take-while shin/take-while)
(def drop-while shin/drop-while)
(def complement shin/complement)
(def rest shin/rest)
(def next shin/next)
(def subvec shin/subvec)
(def reduce shin/reduce)
(def map shin/map)
(def hash shin/hash)

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

(def Unquote shin/Unquote)
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

(def = shin/=)

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
          (recur (str r " " (pr-str x)) (inc i))
          (str r "]"))))

    (satisfies? IPrintable x)
    (-pr-str x)
    
    :else
    (str x)))
(set! shin/pr-str pr-str)

(defn prn [& args]
  (.apply (.-log console) console arguments))

(def str shin/str)

(defn apply [f args]
  (.apply f nil (clj->js args)))

(def clj->js shin/clj->js)
(def js->clj shin/js->clj)

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

;; Tack on prototypes to stuff.
(let [printers [$
                Unquote
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


