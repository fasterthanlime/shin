(ns shin.core)

; FIXME: variadic when, #14 is blocking
(defmacro when [v]
  `(if ~(first v)
     (do ~@(rest v))))
