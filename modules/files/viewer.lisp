(in-package :story)

(defun file-mime (path)
  (string-right-trim '(#\newline) (run/s `(file -i -b ,path))))

(defun render-file-viewer (query path params)
  (setf (content-type*) "text/html")
  (let ((hex (equal "hex" (cdr (assoc "view" params :test #'string=))))
        (type (pathname-type path)))
    (let ((mime (file-mime path)))
      (when-let (pos (position #\; mime))
        (setf mime (subseq mime 0 pos)))
      (if (equal type "html")
          (slurp-file path)
          (html-to-string
            (:html
              (:head
               (:title (fmt "viewing of ~S." query))
               (:link :rel "stylesheet" :type "text/css" :href "/themes/prism.css")
               (:link :rel "stylesheet" :type "text/css" :href "/emoji.css")
               (:link :rel "import" :href "/polymer/polymer/polymer.html")
               (:link :rel "import" :href "/polymer/iron-ajax/iron-request.html")
               (:script :type "text/javascript" :src "/js.js")
               (:script :type "text/javascript" :src "/webcomponentsjs/webcomponents-lite.js")
               (:script :type "text/javascript" :src "/polymer/iron-request.js")
               (:script :type "text/javascript" :src "/files/files.js")
               (:script :type "text/javascript" :src "/files/marked.js")
               (:script :type "text/javascript" :src "/prism/prism.js"))
              (:body
               (cond
                 (hex (htm (:pre (esc (run/s `(hexdump "-C" ,path))))))
                 ((member mime '("text/plain" "text/x-lisp") :test #'string=)
                  (cond
                    ((member type '("css" "js") :test #'string=)
                     (htm (:pre (:code :class (f "language-~A" type)
                                       (esc (slurp-file path))))))
                    ((string= type "md")
                     (htm (:div :id "md"))
                     (script* `(render-markdown "md" ,query)))
                    (t (htm (:pre (esc (slurp-file path)))))))
                 ((member mime '("image/png" "image/jpeg") :test #'string=)
                  (htm (:img :src query)))
                 ((string= mime "application/pdf") (render-pdf-info stream path))
                 ((string= mime "application/gzip") (render-gzip-info stream path))
                 (t (htm (:span (fmt "Unhandled file type ~S." mime))))))))))))

