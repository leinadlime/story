(in-package :story)

(define-demo fabric ((:fabric) :directories (("modules/demo-images" "samples")))
  (:button :onclick (ps (hitme)) "testme")
  (:canvas :width 200 :height 200 :id "c")
  (script
    (defvar *c* (new ((@ fabric *canvas) "c")))
    (defvar *r* (new ((@ fabric *rect)
                      (create :left 100 :top 100
                              :width 20 :height 20
                              :angle 45 :fill "red"))))
    ((@ *c* add) *r*)
    (defvar *i*)
    ((@ fabric *image from-u-r-l) "samples/eye.png"
     (lambda (img) (setf *i* img) ((@ *c* add) img)))
    (defun hitme ()
      ((@ *r* set) (create :left (random 200) :top (random 200)))
      ((@ *i* set) (create :left (random 200) :top (random 200)))
      ((@ *r* set-coords))
      ((@ *i* set-coords))
      ((@ *c* render-all)))))

