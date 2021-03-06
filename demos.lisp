(in-package :story)

(defvar *demos* nil)

(defmacro define-demo (name (&optional modules &rest args) &body body)
  (let ((title (f "Story Demo ~A" (string-capitalize name))))
    `(progn
       (pushnew ',name *demos*)
       (define-story ,(symb 'demo- name) (:title ,title :modules ,modules ,@args)
        (:h1 :style "font-family:sans-serif;" ,title)
        ,@body))))

;; (define-demo trivial ())


