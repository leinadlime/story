(in-package :story)

(define-demo sample-images (:sample-images)
  (iter (for word in (split-sequence #\space "This is a set of test images for your reading pleasure."))
        (htm (:img :alt word :src (format nil "sample-images/~A.png" word)))))