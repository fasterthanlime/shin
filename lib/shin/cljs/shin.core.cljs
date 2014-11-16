(ns shin.core
  (:require-js [shin hamt]))

(defn contains? [coll key]
  (nil? (get coll key)))

(.call (.-intern shin) exports shin)

