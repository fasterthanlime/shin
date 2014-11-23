(ns shin.core)

(defmacro when [cond & body]
  `(if ~cond
     (do ~@body)))

