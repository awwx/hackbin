(def loadval (file)
  (let result nil
    (w/infile f file
      (w/uniq eof
        (whiler e (read f eof) eof
          (= result (eval e)))))
    result))

(def add-statement ((assert hack (o arg)))
  (case assert
     source      (source hack arg)
     prereq      (each x (tolist arg)
                   (prereq hack x))
     apply       (= (kb!apply hack) arg)
     need        (each x (tolist arg)
                   (need hack x))
     patches     (patches hack arg)
     provides    (provide hack arg)
     replaces    (alternative arg hack)
     recommended (recommend hack)
                 (err "unknown assert" assert)))
