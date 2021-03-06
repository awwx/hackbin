;; Recursively expand the recipe with the contents of referenced
;; recipe files.  Note that assertions in the recipe files are
;; applied, but assertions in the recipe itself aren't yet.

(def expand-recipe-files (basedir recipe)
  (let recipe (map symbolify recipe)
    (let (recipe-files non-recipe-files)
         (partition [and (astring _) (recipe-file _)] recipe)
       (each file recipe-files
         (load-recipe-file (full-path basedir file)))
       non-recipe-files)))

; these shenanigans are to get explicit files loaded in order after
; symbolic hacks... but would be better to just append them to the load
; order
;
; no wait, this is wrong: sometimes I want to apply an explicitly
; named hack before symbolic hacks.
 
(def handle-explicit-files (wanted)
  (with (previous-hack nil previous-arc nil)
    (each hack wanted
      (when (and (isa hack 'string) (endmatch ".arc" hack))
        (source hack hack)
        (= kb!filename.hack (filepart hack))
        (when previous-hack (apply-before hack previous-hack))
        (when previous-arc  (apply-before hack previous-arc))
        (= previous-arc hack))
      (= previous-hack hack))))

(def process-recipe (basedir recipe)
  (w/basedir* basedir
    (map apply-datum recipe)
    (handle-explicit-files (qlist kb!wanted))
    t))

;; Resolves needed dependencies, and returns the completed recipe
;; which contains only concrete hacks.

(def satisfy-recipe (basedir recipe)
  (process-recipe basedir recipe)
  (let solution (car (satisfy))
    (unless solution (err "no solution" recipe))
    (load-order solution)))

(def tmpdir ()
  (string "/tmp/" (rand-string 10)))

;; todo the details of how to apply Arc3.1 belongs in a recipe

(def writen (s . xs)
  (each x xs
    (write x s)
    (disp #\newline s)))

(def racket-require (hack)
  `(namespace-require
    (list 'file (string-append _srcdir* ,(hack-filename hack)))))

(def arc3_1-specials ()
  (each hack '(arc3.1/as arc3.1/repl rlwrap)
    (= kb!apply.hack 'special)))

(def copy-file (source-file dest-file)
  (system* "/bin/cp" source-file dest-file))

(def copy-file-into-directory (source-file dest-dir)
  (system* "/bin/cp"
           source-file
           (string dest-dir "/")))

(def recursively-delete (path)
  (system* "/bin/rm" "-rf" path))

(def apply-patch (workdir recipe patch)
  (let to-patch (hack-patched-by patch)
    (unless (mem to-patch recipe)
      (err "hack to patch not in recipe" to-patch))
    (w/cwd workdir
      (system* "/usr/bin/patch"
                "--no-backup-if-mismatch"
                "-p1"
                "-s"
                (hack-filename to-patch)
                (source-file patch)))))

(def apply-hack (workdir recipe hack)
  (case kb!apply.hack
    patch    (apply-patch workdir recipe hack)
    store    nil ;; ??
    arc-load nil
    special  nil
             (err "no application for" hack)))

(implicit background*)

(def background datums
  (= background* (join datums background*)))

(def create-kb ()
  (ret k (new-kb)
    (w/kb k
      (arc3_1-specials)
      (process-recipe nil background*))))

(def empty-destdir (destdir clean)
  (when clean (recursively-delete destdir))
  (when (or (file-exists destdir) (dir-exists destdir))
    (err "destdir exists" destdir))
  (ensure-dir destdir))

(def satisfy-and-apply-recipe (recipe destdir clean)
  (let concrete-recipe (satisfy-recipe basedir* recipe)
    (apply-concrete-recipe kb concrete-recipe destdir clean)))

(def apply-recipe (recipe (o destdir (tmpdir)) (o clean))
  (w/kb (create-kb)
    (w/basedir* cwd
      (satisfy-and-apply-recipe recipe destdir clean))))

(def run-recipe (recipe (o destdir (tmpdir)) (o clean))
  (w/kb (create-kb)
    (w/basedir* cwd
      (satisfy-and-apply-recipe recipe destdir clean)
      ;; should be part of the recipe
      (apply system*
       (+ (if (mem [in _ 'rlwrap "rlwrap"] recipe) ; todo
              '("/usr/bin/rlwrap" "-q" "\""))
          (list (trim (tostring (system "which racket")))
                (string destdir "/" (executable-file))))))))

(def solve (recipe)
  (w/kb (create-kb)
    (w/basedir* cwd
      (write (satisfy-recipe basedir* recipe))
      (prn))))
