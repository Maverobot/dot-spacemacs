;;; org-pandoc-eisvogel-test.el --- Pandoc/Eisvogel export regressions -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)
(require 'ox)
(require 'cl-lib)

(defconst my/org-pandoc-test-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name default-directory))))
  "Root directory of this Spacemacs configuration checkout.")

(defun my/org-pandoc-test-config-block ()
  "Return the Pandoc/Eisvogel Emacs Lisp source block."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "spacemacs.org" my/org-pandoc-test-root))
    (goto-char (point-min))
    (unless (re-search-forward "^\\*+ org-pandoc PDF export$" nil t)
      (error "Pandoc/Eisvogel configuration heading not found"))
    (unless (re-search-forward "^#\\+BEGIN_SRC emacs-lisp\\b.*$" nil t)
      (error "Pandoc/Eisvogel Emacs Lisp block not found"))
    (let ((begin (line-beginning-position 2)))
      (unless (re-search-forward "^#\\+END_SRC$" nil t)
        (error "Unterminated Pandoc/Eisvogel Emacs Lisp block"))
      (buffer-substring-no-properties begin (match-beginning 0)))))

(defun my/org-pandoc-test-command-arguments (options)
  "Return Pandoc arguments for a temporary document containing OPTIONS."
  (let* ((temporary-directory (make-temp-file "org-pandoc-options-" t))
         (input-file (expand-file-name "input.org" temporary-directory))
         (output-file (expand-file-name "output.pdf" temporary-directory))
         pandoc-arguments
         input-buffer)
    (unwind-protect
        (progn
          (with-temp-file input-file
            (insert options "* Heading\nBody\n"))
          (setq input-buffer (find-file-noselect input-file))
          (with-current-buffer input-buffer
            (org-mode)
            (cl-letf (((symbol-function 'executable-find)
                       (lambda (program)
                         (and (string= program "pandoc") "/usr/bin/pandoc")))
                      ((symbol-function 'call-process)
                       (lambda (program &optional _infile _destination _display
                                        &rest arguments)
                         (when (string= program "pandoc")
                           (setq pandoc-arguments arguments))
                         0)))
              (my/org-pandoc-eisvogel-export output-file)))
          pandoc-arguments)
      (when (buffer-live-p input-buffer)
        (kill-buffer input-buffer))
      (when-let ((output-buffer (get-buffer " *org-pandoc-eisvogel*")))
        (kill-buffer output-buffer))
      (delete-directory temporary-directory t))))

(with-temp-buffer
  (insert (my/org-pandoc-test-config-block))
  (eval-buffer))

(ert-deftest my/org-pandoc-eisvogel-honors-toc-and-number-options ()
  "Pandoc flags must follow Org's per-document toc and num options."
  (dolist (case '(("" t t)
                  ("#+OPTIONS: toc:nil\n" nil t)
                  ("#+OPTIONS: num:nil\n" t nil)
                  ("#+OPTIONS: toc:nil num:nil\n" nil nil)))
    (pcase-let* ((`(,options ,expect-toc ,expect-numbering) case)
                 (arguments (my/org-pandoc-test-command-arguments options)))
      (should (eq (and (member "--toc" arguments) t) expect-toc))
      (should (eq (and (member "--number-sections" arguments) t)
                  expect-numbering)))))

;;; org-pandoc-eisvogel-test.el ends here
