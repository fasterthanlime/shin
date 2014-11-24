(ns shin.core
  (:require js/hamt
            js/shin))

(def init shin/init)

(def vec shin/vec)
(def hash-map shin/hash-map)
(def set shin/set)
(def list shin/list)
(def keyword shin/keyword)
(def symbol shin/symbol)
(def get shin/get)
(def empty? shin/empty?)
(def nth shin/nth)
(def nthnext shin/nthnext)
(def seq shin/seq)
(def assoc shin/assoc)
(def dissoc shin/dissoc)
(def count shin/count)
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

(def atom shin/atom)
(def deref shin/deref)
(def reset! shin/reset!)
(def swap! shin/swap!)

(def name shin/name)
(def nil? shin/nil?)
(def not shin/not)

(def dec shin/dec)
(def inc shin/inc)
(def even? shin/even?)
(def odd? shin/odd?)
(def = shin/=)
(def not= shin/not=)
(def + shin/+)
(def - shin/-)
(def * shin/*)
(def / shin//)
(def mod shin/mod)
(def < shin/<)
(def > shin/>)
(def <= shin/<=)
(def >= shin/>=)
(def pr-str shin/pr-str)
(def prn shin/prn)
(def str shin/str)

(def aget shin/aget)
(def aset shin/aset)

(def apply shin/apply)

(def clj->js shin/clj->js)
(def js->clj shin/js->clj)

(def add-watch shin/add-watch)
(def remove-watch shin/remove-watch)

(defn contains? [coll key]
  (not (nil? (get coll key))))

(defn gensym [stem]
  (let [stem (if stem stem "G__")]
    (symbol (str stem (fresh_sym)))))

(def PersistentVector shin/PersistentVector)

(def vector shin/vector)
; (defn vector []
;   ;; can't use variadic function as it relies on `vector` itself..
;   ;; this doesn't work, because currently 'let' introduces an anonymous
;   ;; functions.. and it will have 0 arguments, thus yielding an empty vector
;   (let [args arguments]
;     (PersistentVector.
;       (fn [h]
;         (loop [i 0]
;           (if (< i (.-length args))
;             (do 
;               (debug "Setting vector[" i "] to " (aget args i))
;               (.set hamt i (aget args i) h)
;               (recur (inc i)))))))))

; Internal - do not use
(def --unquote shin/--unquote)
(def --selfcall shin/--selfcall)

