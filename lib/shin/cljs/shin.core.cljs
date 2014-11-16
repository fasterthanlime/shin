(ns shin.core
  (:require-js [shin hamt]))

(defn contains? [coll key]
  (nil? (get coll key)))
