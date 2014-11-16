(ns shin.core
  (:require-js [hamt])
  (:use-js [shin]))

(defn contains? [coll key]
  (not (nil? (get coll key))))

(.call (.-intern shin) exports shin)
(export contains?)

