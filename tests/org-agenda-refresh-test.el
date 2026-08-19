;;; org-agenda-refresh-test.el --- Org agenda refresh regressions -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)

(defconst my/org-agenda-refresh-test-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name default-directory))))
  "Root directory of this Spacemacs configuration checkout.")

(defun my/org-agenda-refresh-test-function (function-name)
  "Return FUNCTION-NAME's definition from the Org agenda source block."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "spacemacs.org" my/org-agenda-refresh-test-root))
    (goto-char (point-min))
    (unless (re-search-forward "^\\*+ org-agenda$" nil t)
      (error "Org agenda configuration heading not found"))
    (unless (re-search-forward "^#\\+BEGIN_SRC emacs-lisp\\b.*$" nil t)
      (error "Org agenda Emacs Lisp block not found"))
    (let ((begin (line-beginning-position 2))
          (end (progn
                 (unless (re-search-forward "^#\\+END_SRC$" nil t)
                   (error "Unterminated Org agenda Emacs Lisp block"))
                 (match-beginning 0)))
          definition)
      (goto-char begin)
      (while (progn
               (skip-chars-forward " \t\n\r")
               (and (< (point) end) (not definition)))
        (let ((form (read (current-buffer))))
          (when (and (eq (car-safe form) 'defun)
                     (eq (nth 1 form) function-name))
            (setq definition form))))
      (or definition
          (error "Org agenda function `%s' not found" function-name)))))

(ert-deftest my/org-agenda-refreshes-before-opening-dispatcher ()
  "Opening the dispatcher must refresh agenda files before interactive dispatch."
  (eval (my/org-agenda-refresh-test-function 'scan-new-agenda-files))
  (eval (my/org-agenda-refresh-test-function
         'my/org-agenda-refresh-and-open))
  (let (events)
    (let ((org-agenda-files nil))
      (cl-letf (((symbol-function 'file-directory-p)
                 (lambda (directory)
                   (equal directory (expand-file-name "~/org/"))))
                ((symbol-function 'directory-files-recursively)
                 (lambda (directory regexp &rest _)
                   (push (list :scan directory regexp) events)
                   '("/tmp/current.org")))
                ((symbol-function 'call-interactively)
                 (lambda (command &optional _record-flag _keys)
                   (push (list :dispatch command org-agenda-files) events))))
        (my/org-agenda-refresh-and-open))
      (should
       (equal (nreverse events)
              (list (list :scan (expand-file-name "~/org/") "\\.org\\'")
                    (list :dispatch 'org-agenda '("/tmp/current.org"))))))))


;;; org-agenda-refresh-test.el ends here
