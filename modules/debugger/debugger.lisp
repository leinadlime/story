(in-package :story)

(define-story-module debugger
  :imports (("debugger" debugger-interface-template))
  :sockets (("/debugger" debugger-socket-handler))
  :depends-on (:polymer :paper-input :files :prism))

(defvar *debugger* nil)

(defclass debugger (websocket-resource) ())

(defmethod text-message-received ((db debugger) client message)
  (let* ((pos (position #\space message))
         (command (if pos (subseq message 0 pos) message))
         (eof (gensym))
         (args (when pos
                 (let ((*read-eval* nil))
                   (with-input-from-string (stream (subseq message pos))
                     (iter
                       (let ((arg (read stream nil eof)))
                         (if (eq arg eof)
                             (return rtn)
                             (collect arg into rtn)))))))))
    (let* ((fn (assoc-value *debugger-commands* command :test 'string=))
           (class :error)
           (rtn (with-output-to-string (*standard-output*)
                  (if fn
                      (handler-case
                          (progn
                            (apply fn args)
                            (setf class :result))
                        (error (c)
                          (debugger-error-handler c)))
                      (debugger-command-not-found command)))))
      (send-text-message client
                         (to-json
                          (list (cons :class class)
                                (cons :message rtn)))))))

(defun debugger-error-handler (condition)
  (let ((stream *standard-output*))
   (html (esc (format t "ERROR: ~A" condition)))))

(defun debugger-command-not-found (name)
  (let ((stream *standard-output*))
    (html (:span "The command " (:b (esc name)) " is unknown."))))

(defun debugger-socket-handler (request)
  (declare (ignore request))
  (or *debugger* (setf *debugger* (make-instance 'debugger))))

(define-template debugger-interface
  :properties (("socket" string "/debugger")
               ("reverse-video" boolean)
               ("onInit" string)
               ("port" number *websocket-port*))
  :style (("#workspace" :background white
                        :border "2px solid #007" :overflow-y auto :padding 10px :margin 10px)
          (".entry" :padding 10px :background "#111" :font-family monospace)
          (".result" :padding 10px :background "#222"
                     :font-family monospace :white-space pre
                     :margin 0px)
          (".result h2" :margin-top 0px)
          ("div.divider" :height 5px :background "#BBB")
          ("div.error" :padding 10px :background "#C00" :color white)
          ;; (".description table" :border-collapse collapse)
          ;; (".description tr.owned")
          (".description h3" :white-space normal)
          (".description th" :text-align left :font-family monospace :padding-right 10px)
          ("code.language-js" :font-family monospace)
          ("span.desc" :color blue :cursor pointer :display inline-block)
          ("span.action" :color blue :cursor pointer)
          ("span.error" :color red)
          (".desc .info" :color green :padding-left 2px :padding-right 2px
                         :max-width 400px :overflow hidden :text-overflow ellipsis
                         :white-space nowrap :display inline-block :vertical-align bottom)
          (".desc .id" :color red :padding-left 2px)
          (".dom" :padding "6px 10px 10px 10px" :background "#DDD")
          (".fn-call" :display inline-block :cursor pointer :color blue :padding 2px)
          (".fn-call-result" :padding 10px :background "#DDD"
                             :font-family monospace :white-space pre
                             :margin 0px :font-size larger)
          (".fn-call-result .name" :padding 4px :margin-bottom 4px)
          ("th" :padding 2px)
          ("td" :text-align left :padding "0px 20px 0px 0px")
          (".error .error-message" :max-width 300px :padding "0px 4px 0px 0px")
          (".system-information" :padding 10px :font-family monospace)
          (".system-information th" :padding-right 20px :text-align right)
          ("span.prestring" :display inline-block :overflow hidden :text-overflow ellipsis
                            :white-space nowrap :max-width 300px)
          ("#repl" :--paper-input-container-input "color:white;"))
  :content ((:div :id "workspace"
                  (input :id "repl" :on-keydown "_handleKeydown" :no-label-float t)))
  :methods
  ((attached ()
             (let* ((url (+ "ws://localhost:" (@ this port) (@ this socket)))
                    (ws (new (*web-socket url))))
               (setf (@ this websocket) ws
                     (@ this commands) (create)
                     (@ ws root) this
                     (@ ws onmessage) (@ this _handle-message)
                     (@ this history) (make-array)
                     (@ this aliases) (create a "alias" c "clear" h "help" d "describe"
                                              fs "fullscreen" e "evaluate" rv "reverse-video"
                                              f "find"))
               (add-command "clear" "clearRepl")
               (add-command "fullscreen" "toggleFullscreen")
               (add-command "dom" "insertDom")
               (add-command "describe" "describe")
               (add-command "alias" "alias")
               (add-command "find" "findDom")
               (add-command "evaluate" "evaluate")
               (add-command "reverse-video" "reverseVideo")
               (add-command "system" "describeSystem")
               (add-command "storage" "describeStorage")
               (when (@ this reverse-video) (reverse-video))
               ((@ this $ repl focus))
               (console "debugger connected to" url)
               (when (@ this on-init)
                 (funcall (@ this (@ this on-init))))))
   (alias (&optional from to)
          (if from
              (if to
                  (progn
                    (setf (aref (@ this aliases) from) to)
                    (insert-text (+ "Alias for \"" from "\" set.")))
                  (insert-error "Missing TO in alias FROM TO."))
              (let ((table (dom :table)))
                (loop for (k v) of (@ this aliases)
                      do (append-child table
                                       (dom :tr
                                            (dom :th k)
                                            (dom :td v))))
                (insert table))))
   (alias-of (string) (or (aref (@ this aliases) string) string))
   (insert (&rest els)
           (loop for el in els
                 do (with-content (repl)
                      (when (story-js::aand (@ repl previous-sibling) (has-class it "result"))
                        (insert-before (parent-node repl) (dom (:div "divider")) repl))
                      (insert-before (parent-node repl) el repl)
                      (flush-dom)
                      ((@ repl focus)))))
   (insert-text (text &key class-name) (insert (dom (:div class-name) text)))
   (insert-error (text) (insert-text (+ "ERROR: " text) :class-name "error"))
   (_handle-message (event)
                    (let ((rtn ((@ *J-s-o-n parse) (@ event data)))
                          (that (@ this root)))
                      (with-slots (class message) rtn
                        (insert
                         (dom (:div class nil message))))))
   (add-command (command fn) (setf (aref (@ this commands) command) fn))
   (evaluate (&rest args)
             (let* ((cmd ((@ args join) " "))
                    (rtn (try (eval cmd) (:catch (e) e))))
               (console cmd "⟹  " rtn)
               (insert (dom (:div "result") "⟹  " (present rtn)))))
   (_prototypes-of (el)
                   (when (objectp el)
                     (loop
                       for pro = (get-prototype-of el) :then (get-prototype-of pro)
                       while pro
                       collect pro)))
   (_parse_id (arg)
              (or ((@ document query-selector) arg)
                  (progn
                    (insert-error (+ "ID \"" arg "\" does not exist."))
                    nil)))
   (_insert-dom-recur (rows el indent fields)
                      (let ((obj this))
                        ((@ rows push)
                         (dom :tr
                              (dom :td
                                   (dom (:div nil ((style (+ "padding-left:" (* indent 20) "px"))))
                                        (present el)))
                              (loop for field in fields
                                    collect
                                    (dom :td ((@ obj present) (getprop el field))))
                                        ;(dom :td (@ el class-name))
                                        ;(dom :td (@ el id))
                              )))
                      (unless (eql el this)
                        (loop for child in (@ el children)
                              do (_insert-dom-recur rows child (1+ indent) fields))))
   (insert-dom (arg &rest fields)
               (let ((root (if arg (_parse_id arg) document))
                     (rows (make-array)))
                 (_insert-dom-recur rows root 0 fields)
                 (insert (dom (:div "dom") (dom :table rows)))))
   (_describe (el &key fn-this (show-prototypes t))
              (console :describe el)
              (let ((obj this))
                (dom (:div "result description")
                     (dom :h2 ((@ obj present) el))
                     (when (and show-prototypes (objectp el))
                       (dom :h3 (loop for pro in ((@ obj _prototypes-of) el)
                                      collect ((@ obj present) pro)
                                      collect (text " "))))
                     (dom :table
                          (loop for key of el
                                collect
                                (dom (:tr (when ((@ el has-own-property) key) "owned"))
                                     (dom :th key)
                                     (dom :td ((@ obj present)
                                               (try
                                                (aref el key)
                                                (:catch (error) error))
                                               el)))))
                     (cond
                       ((ignore-errors (eql (@ el node-name) "STYLE"))
                        (let ((pre
                                (dom :pre
                                     (dom (:code "language-css") (@ el inner-text)))))
                          ((@ *prism highlight-element) (@ pre first-child))
                          pre))
                       ((functionp el)
                        (let ((pre
                                (dom :pre
                                     (dom (:code "language-js") ((@ el to-string))))))
                          ((@ *prism highlight-element) (@ pre first-child))
                          (list pre
                                (dom (:div "fn-call" ((tab-index 1)
                                                      ((on-tap on-keypress) "_fnCall")
                                                      (_fn el)
                                                      (_fn-this fn-this)))
                                     "call"
                                     (when (plusp (@ el length))
                                       (dom (:span "fn-args" ((style "visibility:hidden;")))
                                            (loop for x from 1 to (@ el length)
                                                  collect (dom (:input "arg"
                                                                 ((type "text")
                                                                  (style "width:50px;margin-left:10px;")))))))))))))))
   (_fn-call-complete (fn fn-this args)
                      (let ((result (try ((@ fn apply) fn-this args) (:catch (e) e))))
                        (console :call fn-this fn args :result result)
                        (insert
                         (dom (:div "fn-call-result")
                              (dom (:span "name") (+
                                                   (ignore-errors (@ fn-this constructor name))
                                                   "."
                                                   (@ fn name) "("
                                                   args
                                                   ") ⟹  "))
                              (present result)))))
   (_verify-call-arguments (fn el args)
                           (setf (@ args style visibility) "visible")
                           (loop for arg in (@ args children)
                                 when (= 0 (@ arg value length))
                                   do ((@ arg focus))
                                      (return nil)
                                 finally (return t)))
   (_fn-call (event)
             (when-enter-or-tap
              (when (eql (@ el local-name) "input")
                (when (eql (@ event type) "tap") (return))
                (setf el (@ el parent-node parent-node)))
              (let* ((fn (@ el _fn))
                     (fn-this (@ el _fn-this))
                     (args ((@ el query-selector) ".fn-args")))
                (if (plusp (@ fn length))
                    (when (_verify-call-arguments fn el args)
                      (_fn-call-complete fn fn-this
                                         (loop for child in (@ args children)
                                               collect (eval (@ child value)))))
                    (_fn-call-complete fn fn-this)))))
   (describe (arg)
             (insert
              (_describe
               (if (and (stringp arg) ((@ arg starts-with) "#"))
                   (or (id ((@ arg substr) 1))
                       (progn
                         (insert-error (+ "ID \"" arg "\" does not exist."))
                         nil))
                   (try (eval arg) (:catch (e) e))))))
   (_handle-command (full-command)
                    ((@ this history push) full-command)
                    (with-content (repl)
                      (let* ((pos ((@ full-command index-of) " "))
                             (command (if (plusp pos) ((@ full-command substr) 0 pos) full-command))
                             (args (when (plusp pos) ((@ full-command substr) (1+ pos)))))
                        (let ((fn (aref (@ this commands) (alias-of command))))
                          (if fn
                              (progn
                                (apply (aref this fn) (and args ((@ args split) " ")))
                                nil)
                              (+ (alias-of command)
                                 (if args (+ " " args) "")))))))
   (_handle-keydown (event)
                    (with-content (workspace repl)
                      (with-slots (history history-index) this
                        (cond
                          ((eql (@ event key) "Enter")
                           (let ((value (@ repl value)))
                             (when (plusp (@ value length))
                               (insert (dom (:div "entry") value))
                               (setf (@ repl value) "")
                               (let ((remote-command (_handle-command value)))
                                 (when remote-command
                                   ((@ this websocket send) remote-command))))))
                          ((eql (@ event key) "ArrowUp")
                           (when (and (plusp (length history))
                                      (< history-index (length history)))
                             (setf history-index (+ history-index 1)
                                   (@ repl value) (aref history (- (length history) history-index)))))
                          ((eql (@ event key) "ArrowDown")
                           (when (plusp history-index)
                             (let ((next (if (= history-index 1)
                                             ""
                                             (aref history (- (length history) history-index -1)))))
                               (setf (@ repl value) next
                                     history-index (- history-index 1)))))
                          (t (setf (@ this history-index) 0) nil)))))
   (_handle-present-event (event)
                          (when-enter-or-tap
                           (insert (_describe (@ el presenting)
                                              :fn-this (@ el _fn-this)))))
   (_handle-text-expansion (event)
                           (when-enter-or-tap
                            (let ((style (@ el style)))
                              (setf (@ style white-space)
                                    (if (eql (@ style white-space) "normal")
                                        "nowrap" "normal")))))
   (_shorten-href (href)
                  (if ((@ href starts-with) "http://localhost")
                      (+ "lo" ((@ href substr) 16))
                      href))
   (_present-error (el)
                   (dom (:span "error-message")
                        (+ ": " (@ el message))
                        (dom (:span "more" (((on-tap on-keypress) "_expandError")
                                            (stack (@ el stack))
                                            (tab-index 1)))
                             " …")))
   (_expand-error (event)
                  (when-enter-or-tap
                   (setf (@ el text-content)
                         (if (@ el expanded)
                             " …"
                             ((@ el stack substr) ((@ el stack index-of) #\newline)))
                         (@ el expanded) (not (@ el expanded)))))))

(define-template-method debugger-interface describe-system ()
  (let ((n (@ window navigator))
        (el this))
    (insert
     (dom (:div "system-information")
          (dom :table
               (loop for key in '("userAgent"
                                  "appName"
                                        ; "appCodeName" "appVersion"
                                  "platform" "product"
                                  "language" "languages"
                                  "onLine" "cookieEnabled"
                                  "doNotTrack")
                     collect (dom :tr
                                  (dom :th key)
                                  (dom :td ((@ el present) (getprop n key))))))))))

(define-template-method debugger-interface toggle-fullscreen ()
  (with-content (workspace)
    (with-slots (s-position s-top s-right s-bottom s-left s-padding s-margin
                 s-border)
        workspace
      (with-slots (position top right bottom left padding margin border)
          (@ workspace style)
        (if (@ workspace fullscreen)
            (setf position s-position top s-top right s-right bottom
                  s-bottom left s-left margin s-margin padding s-padding
                  border s-border)
            (setf s-position position position "absolute" s-top top top 0
                  s-right right right 0 s-bottom bottom bottom 0
                  s-left left left 0 s-margin margin margin 0
                  s-padding padding padding 10
                  s-border border border 0))))
    (setf (@ workspace fullscreen) (not (@ workspace fullscreen)))))

(define-template-method debugger-interface reverse-video ()
  (setf (@ this reverse-video-set) (not (@ this reverse-video-set)))
  (with-content (workspace)
    (cond
      ((@ this reverse-video-set)
       (setf (@ workspace style border-color) "black"
             (@ workspace style background) "black"
             (@ workspace style color) "white"))
      (t
       (setf (@ workspace style border-color) "#007"
             (@ workspace style background) "white"
             (@ workspace style color) "black")
       )))
)

(define-template-method debugger-interface find-dom (arg)
  (let ((els ((@ document query-selector-all) arg)))
    (console els)
    (loop for el in els
          do (insert (present el)))))

(define-template-method debugger-interface clear-repl ()
  ((@ console clear))
  (with-content (workspace)
    (loop for child in (child-nodes workspace)
          do (unless (eql (@ child id) "repl")
               (remove-child workspace child)))))

(define-template-method debugger-interface describe-storage ()
  (insert
   (dom (:div "storage-information")
        (dom :h3 "local")
        (_describe (@ window local-storage) :show-prototypes nil)
        (dom :h3 "session")
        (_describe (@ window session-storage) :show-prototypes nil))))

(export '(debugger-interface))
