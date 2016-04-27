(in-package :story)

(defparameter *build-location* (story-file "build/"))

(defvar *story* nil)

(defvar *stories* (make-hash-table :test 'equal))

(defun add-story (story)
  (when (gethash (name story) *stories*)
    (warn "Redefining story ~S." (name story)))
  (setf (gethash (name story) *stories*) story
        *story* story))

(defmacro do-stories ((name story) &body body)
  `(iter (for (,name ,story) in-hashtable *stories*)
         (progn ,@body)))

(defun stories ()
  "Show all the stories and their contents."
  (iter (for (name story) in-hashtable *stories*)
        (for index from 1)
        (format t "~A.~A ~S~%" index (if (eq story *story*) "*" " ") story)
        (iter (for child in (children story))
              (format t "      ~S~%" child))))

(defclass element ()
  ((parent :reader parent :initform nil :initarg :parent)
   (children :reader children :initform nil :initarg :children)))

(defmethod add-child ((parent element) (child element))
  (cond
    ((member child (children parent))
     (warn "~S is already a child of ~S." child parent))
    (t
     (when (parent child)
       (warn "Replacing parent of ~S ~S with ~S." child (parent child) parent))
     (setf (slot-value child 'parent) parent
           (slot-value parent 'children) (append (children parent) (list child))))))

(defclass story (element)
  ((name :reader name :initarg :name)
   (title :reader title :initarg :title :initform "Unititled Story")
   (home :reader home :initarg :home)
   (modules :reader modules :initarg :modules)))

(defmethod print-object ((story story) stream)
  (print-unreadable-object (story stream :type t)
    (format stream "~A" (name story))))

(defclass page (element)
  ((path :reader path :initarg :path)
   (title :reader title :initform nil :initarg :title)
   (renderer :reader renderer :initarg :renderer)
   (body :reader body :initarg :body)))

(defmethod print-object ((page page) stream)
  (print-unreadable-object (page stream :type t)
    (format stream "~A" (path page))))

(defmethod render-complete-page ((page page) stream)
  (let* ((story (parent page))
         (title (or (title page) (title story))))
    (with-html-output (stream stream)
      (:html
        (:head
         (fmt "~%<!-- ~A ~A ~A -->~%" (name (parent page)) (git-latest-commit) (format-timestring nil (now)))
         (when title (htm (:title (esc title)))))
        (:body (funcall (body page) stream page))))))

(defmacro define-story (name (&key title modules) &body body)
  `(let* ((page (make-instance 'page :path "index.html" :renderer 'render-complete-page
                               :body (lambda (stream page)
                                       (declare (ignorable page))
                                       (html ,@body))))
          (story (make-instance 'story :name ,(string-downcase name) :title ,title
                                :home page :modules ',modules)))
     (add-child story page)
     (add-story story)))

(defun build-stories ()
  (do-stories (name story)
    (build story)))

(defgeneric render (element stream)
  (:method :before ((element element) stream)
           (note "rendering ~S" element))
  (:method ((element element) stream)
    (iter (for child in (children element))
          (render child stream)))
  (:method ((page page) stream)
    (funcall (renderer page) page stream)
    (call-next-method)))

(defun render-current-story ()
  (with-output-to-string (stream)
    (render *story* stream)))
