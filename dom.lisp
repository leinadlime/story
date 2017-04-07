(in-package :story)

(defpsmacro dom (args &rest children)
  (destructuring-bind (node-type &optional class-name properties inner-html) (ensure-list args)
    (let ((el (gensym))
          (ch (gensym)))
      `(let ((,el ((@ document create-element) ,node-type)))
         ,@(when class-name `((aand ,class-name (add-class ,el it))))
         ,@(when inner-html `((setf (getprop ,el 'inner-h-t-m-l) ,inner-html)))
         ,@(when properties
             (loop for (k v) in properties
                   collect
                      (if (story:starts-with-p (string-downcase k) "on-")
                          `((@ this listen) ,el ,(subseq (string-downcase k) 3) ,v)
                          `(setf (aref ,el ',k) ,v))))
         ,@(when children
             (loop for child in children
                   collect `(let ((,ch ,child))
                              (when ,ch
                                (if (arrayp ,ch)
                                    (loop for c in ,ch
                                          do ((@ ,el append-child)
                                              (if (and c (@ c node-type)) c (text c))))
                                    ((@ ,el append-child)
                                     (if (and ,ch (@ ,ch node-type)) ,ch (text ,ch))))))))
         ,el))))

