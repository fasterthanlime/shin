(ns cljs.core)

(defmacro when [cond & body]
  `(if ~cond
     (do ~@body)))

(defmacro when-not [cond & body]
  `(when (not ~cond) ~@body))

(defmacro assert [cond message]
  `(when-not ~cond (throw (js/Error. message))))

