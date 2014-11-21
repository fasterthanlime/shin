(ns shin.core)

(defmacro when [v]
  `(if ~(first v)
     (do ~@(rest v))))
