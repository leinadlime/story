(in-package :story)

(define-story-module editor
  :scripts ("ace/ace.js")
  :directories ("ace")
  :depends-on (:polymer :files))
