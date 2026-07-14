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

(ert-deftest my/python-lsp-session-sanitizer-preserves-unrelated-state ()
  "Sanitation must remove Python multi-root maps and preserve other state."
  (let* ((block (my/python-lsp-test-org-block
                 "Prune deleted LSP workspace folders"))
         (temporary-directory (make-temp-file "python-lsp-session-" t))
         (existing-directory (expand-file-name "existing" temporary-directory))
         (missing-directory (expand-file-name "missing" temporary-directory))
         (session-file (expand-file-name "session.el" temporary-directory))
         (block-file (expand-file-name "session-sanitizer.el" temporary-directory))
         (result
          (progn
            (make-directory existing-directory t)
            (my/python-lsp-test-run-child
             `(progn
                (require 'package)
                (setq package-user-dir ,(my/python-lsp-test-package-dir))
                (package-initialize)
                (setq lsp-session-file ,session-file)
                (write-region ,block nil ,block-file)
                (byte-compile-file ,block-file)
                (load (concat ,block-file "c") nil 'nomessage)
                (require 'lsp-mode)
                (let ((server-map (make-hash-table :test 'equal)))
                  (puthash 'pyright (list ,existing-directory) server-map)
                  (puthash 'pyright-remote (list ,existing-directory) server-map)
                  (puthash 'ruff (list ,existing-directory) server-map)
                  (puthash 'clangd (list ,existing-directory) server-map)
                  (setq lsp--session
                        (make-lsp-session
                         :folders (list ,existing-directory
                                        ,missing-directory
                                        ,existing-directory)
                         :folders-blocklist (list ,existing-directory)
                         :server-id->folders server-map)))
                (my/lsp-prune-missing-workspace-folders)
                (my/lsp-prune-missing-workspace-folders)
                (unless (equal (lsp-session-folders (lsp-session))
                               (list ,existing-directory))
                  (error "Unexpected global folders: %S"
                         (lsp-session-folders (lsp-session))))
                (unless (equal (lsp-session-folders-blocklist (lsp-session))
                               (list ,existing-directory))
                  (error "Blocklist changed"))
                (dolist (server-id '(pyright pyright-remote ruff))
                  (when (gethash server-id
                                 (lsp-session-server-id->folders (lsp-session)))
                    (error "Target mapping survived: %S" server-id)))
                (unless (equal
                         (gethash 'clangd
                                  (lsp-session-server-id->folders (lsp-session)))
                         (list ,existing-directory))
                  (error "Unrelated mapping changed")))))))
    (unwind-protect
        (ert-info ((cdr result))
          (should (= 0 (car result))))
      (delete-directory temporary-directory t))))

;;; python-lsp-isolation-test.el ends here
