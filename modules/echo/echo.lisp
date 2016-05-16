(in-package :story)

(define-story-module echo
  :scripts ("echo.js" ("init-echo.js" init-echo))
  :files ("blank.png"))

(in-package :story-js)

(define-script init-echo
  (defvar *echo-initialized*)

  (defun initialize-echo ()
    (when *echo-initialized* (console "Re-initializing echo."))
    (setf *echo-initialized* t)
    ((@ echo init)
     (create :offset 100
             :throttle 250
             :unload nil
             :callback (lambda (el op) (console el op)))))

  (defun echo-watch (id)
    ((@ (id id) add-event-listener) "content-scroll" echo-handle-scroll))

  (defun echo-handle-scroll ()
    ((@ echo render)))

  )


