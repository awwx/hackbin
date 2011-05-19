(def executable-file (kb)
  (or kb!executable "as.scm"))

(def apply-arc3_1-as (kb workdir recipe)
  (let executable (string workdir "/" (executable-file kb))
    (w/outfile s executable
      (disp "#!/usr/bin/env racket\n" s)
      (disp "#lang racket/load\n" s)
      (writen s `(require racket))
      (writen s `(define _srcdir*
                   (path->string
                    (let-values (((base _2 _3) (split-path (normalize-path (find-system-path 'run-file)))))
                      base))))
      (when (mem 'arc3.1/ac recipe)
        (writen s (racket-require 'arc3.1/ac)))
      (when (mem 'arc3.1/brackets recipe)
        (writen s (racket-require 'arc3.1/brackets)
                `(use-bracket-readtable)))
      (each hack recipe
        (when (is kb!apply.hack 'arc-load)
          (writen s `(aload (string-append _srcdir* ,(hack-filename hack))))))
      (when (mem 'arc3.1/repl recipe)
        (writen s `(tl))))
    (system* "/bin/chmod" "+x" executable)))

(def apply-concrete-recipe (kb recipe destdir clean)
  (w/kb kb
    (aif (keep ~concrete recipe) (err "abstract hacks in recipe:" it))
    (empty-destdir destdir clean)  
    (each hack recipe
      (when (in kb!apply.hack 'arc-load 'store)
        (copy-file (source-file hack) (string destdir "/" (hack-filename hack)))))
    (each hack recipe
      (apply-hack destdir recipe hack))
    (when (mem 'arc3.1/as recipe)
      (apply-arc3_1-as kb destdir recipe))))

(def technique-kb (technique)
  (let kb (new-kb)
    (w/kb kb (arc3_1-specials))
    (w/kb kb (load-technique technique))
    kb))

(def apply-recipe1 (technique recipe destdir clean)
  (let kb (technique-kb technique)
    (apply-concrete-recipe kb recipe destdir clean)))
