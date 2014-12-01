(ns cljs.core)

(defmacro ->
  ([x]
   x)
  ([x & forms]
   (let [[y & ys] forms
         s        (if (list? y) y (list y))
         [b & a] s]
     `(-> (~b ~x ~@a) ~@ys))))

(defmacro some->
  ([x]
   x)
  ([x & forms]
   (let [[y & ys] forms
         s        (if (list? y) y (list y))
         [b & a] s])
   `(let [x# (~b ~x ~@a)] (if x# (some-> x# ~@ys) nil))))

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
  `(when (not ~cond) ~@body))

(defmacro if-not [cond & body]
  `(if (not ~cond) ~@body))

(defmacro when-let [[x y] & body]
  `(let [~x ~y]
     (if ~x (do ~@body) nil)))

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

