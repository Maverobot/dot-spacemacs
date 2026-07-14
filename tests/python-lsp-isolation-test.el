;;; python-lsp-isolation-test.el --- Python LSP isolation regressions -*- lexical-binding: t; -*-

(require 'ert)
(require 'package)

(defconst my/python-lsp-test-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name default-directory))))
  "Root directory of this Spacemacs configuration checkout.")

(defun my/python-lsp-test-package-dir ()
  "Return the package directory used by isolated child Emacs tests."
  (or (getenv "SPACEMACS_TEST_PACKAGE_DIR")
      (expand-file-name "elpa/30.2/develop" user-emacs-directory)))

(defun my/python-lsp-test-org-block (heading)
  "Return the first Emacs Lisp source block under HEADING."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "spacemacs.org" my/python-lsp-test-root))
    (goto-char (point-min))
    (unless (re-search-forward
             (format "^\\*+ %s$" (regexp-quote heading)) nil t)
      (error "Heading not found: %s" heading))
    (unless (re-search-forward "^#\\+BEGIN_SRC emacs-lisp\\b.*$" nil t)
      (error "No Emacs Lisp block under: %s" heading))
    (let ((begin (line-beginning-position 2)))
      (unless (re-search-forward "^#\\+END_SRC$" nil t)
        (error "Unterminated Emacs Lisp block under: %s" heading))
      (buffer-substring-no-properties begin (match-beginning 0)))))

(defun my/python-lsp-test-run-child (form)
  "Run FORM in a clean child Emacs and return (STATUS . OUTPUT)."
  (let* ((emacs (expand-file-name invocation-name invocation-directory))
         (script (make-temp-file "python-lsp-isolation-" nil ".el"
                                 (prin1-to-string form))))
    (unwind-protect
        (with-temp-buffer
          (let ((status (call-process emacs nil t nil "-Q" "--batch" "-l" script)))
            (cons status (buffer-string))))
      (delete-file script))))

(ert-deftest my/python-lsp-clients-register-as-single-root ()
  "The early configuration must disable multi-root before registration."
  (let* ((block (my/python-lsp-test-org-block
                 "Isolate Python LSP servers by project"))
         (result
          (my/python-lsp-test-run-child
           `(progn
              (require 'package)
              (setq package-user-dir ,(my/python-lsp-test-package-dir))
              (package-initialize)
              (with-temp-buffer
                (insert ,block)
                (eval-buffer))
              (require 'lsp-pyright)
              (require 'lsp-ruff)
              (dolist (server-id '(pyright pyright-remote ruff))
                (let ((client (gethash server-id lsp-clients)))
                  (unless client
                    (error "Client was not registered: %S" server-id))
                  (when (lsp--client-multi-root client)
                    (error "Client remained multi-root: %S" server-id))))))))
    (ert-info ((cdr result))
      (should (= 0 (car result))))))

;;; python-lsp-isolation-test.el ends here
