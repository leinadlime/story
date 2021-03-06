(in-package :story)

(defgeneric render (element stream)
  (:method :before ((element element) stream)
    (note "rendering ~S" element))
  (:method ((element element) stream)
    (iter (for child in (children element))
      (render child stream)))
  (:method ((page page) stream)
    (funcall (renderer page) page stream)
    (call-next-method)))

(defun render-meta-tags (story stream)
  (let ((*attribute-quote-char* #\"))
    (html
      (iter (for (name content) in (meta-tags story))
        (if (consp name)
            (htm (:meta :http-equiv (car name) :content content))
            (htm (:meta :name name :content content)))))))

(defun render-stylesheets (story stream)
  (html
    (iter (for css in (stylesheets story))
      (htm (:link :rel "stylesheet" :type "text/css" :href (ensure-css-extension css))))))

(defun render-scripts (story stream)
  (html
    (iter (for script in (scripts story))
      (htm (:script :type "text/javascript" :src script)))))

(defun render-imports (story stream)
  (html
    (iter (for import in (imports story))
      (htm (:link :rel "import" :href import)))))

(defun render-suffixes (story stream)
  (iter (for suffix in (suffixes story))
    (princ (slurp-file (f "~A/~A" (story-file) suffix)) stream)))

(defun render-prefixes (story stream)
  (iter (for prefix in (prefixes story))
    (princ (slurp-file (f "~A/~A" (story-file) prefix)) stream)))

(defmethod render-complete-page ((page page) stream)
  (let* ((story (parent page))
         (title (or (title page) (title story))))
    (with-html-output (stream stream)
      (:html
        (when (header story) (funcall (header story) stream))
        (:head
         (fmt "~%<!-- ~A ~A ~C ~A -->~%" (name (parent page)) (git-latest-commit) (clock-face) (format-timestring nil (now)))
         (when title (htm (:title (esc title))))
         (cond
           (*production*
            (when (meta-tags story) (render-meta-tags story stream))
            (when (imports story) (htm (:link :rel "import" :href "all.html")))
            (when (stylesheets story) (htm (:link :rel "stylesheet" :type "text/css"
                                                  :href "css-all.css")))
            (when (scripts story) (htm (:script :type "text/javascript" :src "js-all.min.js"))))
           (t
            (when (meta-tags story) (render-meta-tags story stream))
            (when (imports story) (render-imports story stream))
            (when (stylesheets story) (render-stylesheets story stream))
            (when (scripts story) (render-scripts story stream)))))
        (:body :class (body-class page)
               (when (prefixes story) (render-prefixes story stream))
               (funcall (body page) stream page)
               (when (suffixes story) (render-suffixes story stream))
               (when-let ((init (script-init story)))
                 (htm (:script (str (apply #'ps* init))))))
        (when (footer story) (funcall (footer story) stream))))))
