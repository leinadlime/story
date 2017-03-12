(in-package :story)

(define-story-module files
  :stylesheets (("files.css" files-css))
  :scripts (("files.js" files))
  :depends-on (:iron-request :images))

(defun create-file-listing (directory)
  (iter (for file in (directory-files directory))
    (unless (string= (pathname-name file) ".file-listing")
      (multiple-value-bind (description mime) (magic file)
        (collect (nconc (list (cons :name (pathname-name file))
                              (cons :type (pathname-type file))
                              (cons :mime mime)
                              (cons :description description))
                        (additional-file-information (ksymb (string-upcase mime)) file)))))))

(defgeneric additional-file-information (type file)
  (:method (type file) (warn "Unhandled file type ~S." type))
  (:method ((type (eql :image/png)) file)
    (multiple-value-bind (w h) (png-image-size file)
      (list (cons :width w) (cons :height h))))
  (:method ((type (eql :image/jpeg)) file)
    (multiple-value-bind (w h) (jpeg-image-size file)
      (list (cons :width w) (cons :height h)))))

(defun save-file-listing (directory)
  (let ((filename (format nil "~A.file-listing" directory)))
    (with-output-to-file (stream filename
                                 :if-does-not-exist :create :if-exists :overwrite)
      (json:encode-json (create-file-listing directory) stream)
      (note "Wrote ~S." filename))))

(in-package :story-js)

(define-script files
  (defun fetch-file-listing (url callback)
    (request (+ "/" url "/.file-listing")
             (lambda (val) (funcall callback (eval (+ "(" (@ val response) ")"))))))

  (defun render-file-listing (container url &key headings)
    (let* ((div (id container))
           (table (create-element "table" div)))
      (when headings
        (set-html* (create-element "tr" table)
                   (:th "name") (:th "type") (:th "width") (:th "height")
                   (:th "description")))
      (fetch-file-listing
       url
       (lambda (rows)
         (setf (@ div rows) rows)
         (loop for row in rows
               do (let ((tr (create-element "tr" table)))
                    (set-html* tr
                               ((:td :nowrap t) (@ row name))
                               (:td (@ row mime))
                               (:td (@ row width))
                               (:td (@ row height))
                               (:td (@ row description))))))))))

(in-package :story-css)

(defun files-css ()
  (css
   '()))
