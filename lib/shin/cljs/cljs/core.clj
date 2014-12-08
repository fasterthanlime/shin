(ns cljs.core)

(def *assert* true)

(defmacro or
  ([] nil)
  ([x] x)
  ([x & rest]
   `(let [x# ~x] (if x# x# ~(apply or rest)))))

(defmacro and
  ([] true)
  ([x] x)
  ([x & rest]
   `(let [x# ~x] (if (not x#) x# ~(apply and rest)))))

(defmacro binding
  ([bindings & body]
   (let [pairs (partition 2 bindings)
         quads (map #(list* (gensym "save") (gensym "conf") %) pairs)]
     `((fn []
         (try
           ~@(map (fn [[save conf sym val]] `(declare-and-set! ~save ~sym)) quads)
           ~@(map (fn [[save conf sym val]] `(declare-and-set! ~conf ~val)) quads)
           ~@(map (fn [[save conf sym val]] `(set! ~sym ~conf)) quads)
           ~@body
           (finally
             ~@(map (fn [[save conf sym val]] `(set! ~sym ~save)) quads))))))))

(defmacro ->
  ([x]
   x)
  ([x & forms]
   (let [[y & ys] forms
         s        (if (list? y) y (list y))
         [b & a] s]
     `(-> (~b ~x ~@a) ~@ys))))

(defmacro doto
  ([x]
   x)
  ([x & forms]
   (let [[y & ys] forms
        s         (if (list? y) y (list y))
        [b & a] s]
   `(let [x# ~x]
      (~b x# ~@a)
      (doto x# ~@ys)))))

(defmacro some->
  ([x]
   x)
  ([x & forms]
   (let [[y & ys] forms
         s        (if (list? y) y (list y))
         [b & a] s])
   `(if ~x
      (let [x# (~b ~x ~@a)]
        (some-> x# ~@ys))
      nil)))

(defmacro ->>
  ([x]
   x)
  ([x & forms]
   (let [[y & ys] forms
         s        (if (list? y) y (list y))]
     `(->> (~@s ~x) ~@ys))))

(defmacro when [cond & body]
  `(if ~cond
     (do ~@body)
     nil))

(defmacro when-not [cond & body]
  (apply when `(not ~cond) body))

(defmacro if-not [cond & body]
  `(if (not ~cond) ~@body))

(defmacro when-let [[x y] & body]
  `(let [~x ~y]
     (if ~x (do ~@body) nil)))

(defmacro when-some [[x y] & body]
  `(let [~x ~y]
     (if (nil? ~x) nil (do ~@body))))

(defmacro if-let [[x y] & body]
  `(let [~x ~y]
     (if ~x ~@body)))

(defmacro assert
  ([cond]
   (assert cond "Assert failed"))
  ([cond message]
   `(when-not ~cond (throw (js/Error. ~message)))))

(defmacro exists? [something]
  `(*js-bop != "undefined" (*js-uop typeof ~something)))

(defmacro lazy-seq [& body]
  `(LazySeq. (fn [] ~@body) nil))

(defmacro dotimes [[sym max] & body]
  `(loop [~sym 0]
     (if (< ~sym ~max)
       (do
         ~@body
         (recur (inc ~sym))))))

(defmacro js-delete [obj prop]
  `(*js-uop delete (aget ~obj ~prop)))

(defmacro case [x & clauses]
  (let [cases     (partition 2 clauses)
        un-cases  (map
                    #(let [[l r] %]
                       (if (list? l)
                         (interleave l (repeat r))
                         %))
                    cases)
        default   (if
                    (odd? (count clauses))
                    (last clauses)
                    'nil)]
    `(condp = ~x
       ~@(apply concat un-cases) ; poor ☃'s flatten 
       :else ~default)))

