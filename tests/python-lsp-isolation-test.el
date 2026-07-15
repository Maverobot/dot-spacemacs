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

(defun my/python-lsp-test-write-executable (path output)
  "Write an executable at PATH that consumes stdin and prints OUTPUT."
  (make-directory (file-name-directory path) t)
  (write-region
   (format "#!/bin/sh\nwhile IFS= read -r line; do :; done\nprintf '%%s\\n' %S\n"
           output)
   nil path)
  (set-file-modes path #o755))

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
                (let ((missing-key (make-symbol "missing-key"))
                      (server-map
                       (lsp-session-server-id->folders (lsp-session))))
                  (dolist (server-id '(pyright pyright-remote ruff))
                    (unless (eq (gethash server-id server-map missing-key)
                                missing-key)
                      (error "Target mapping key survived: %S" server-id))))
                (unless (equal
                         (gethash 'clangd
                                  (lsp-session-server-id->folders (lsp-session)))
                         (list ,existing-directory))
                  (error "Unrelated mapping changed"))
                (let ((persisted-session
                       (lsp--read-from-file lsp-session-file)))
                  (unless persisted-session
                    (error "Sanitized session was not persisted"))
                  (unless (equal (lsp-session-folders persisted-session)
                                 (list ,existing-directory))
                    (error "Unexpected persisted folders: %S"
                           (lsp-session-folders persisted-session)))
                  (unless (equal
                           (lsp-session-folders-blocklist persisted-session)
                           (list ,existing-directory))
                    (error "Persisted blocklist changed"))
                  (let ((missing-key (make-symbol "missing-key"))
                        (server-map
                         (lsp-session-server-id->folders persisted-session)))
                    (dolist (server-id '(pyright pyright-remote ruff))
                      (unless (eq (gethash server-id server-map missing-key)
                                  missing-key)
                        (error "Persisted target key survived: %S"
                               server-id))))
                  (unless (equal
                           (gethash
                            'clangd
                            (lsp-session-server-id->folders persisted-session))
                           (list ,existing-directory))
                    (error "Persisted unrelated mapping changed"))))))))
    (unwind-protect
        (ert-info ((cdr result))
          (should (= 0 (car result))))
      (delete-directory temporary-directory t))))

(ert-deftest my/python-lsp-watcher-ignores-update-global-default-from-local-load ()
  "Early LSP loading must update global watcher defaults, not a local binding."
  (let* ((block (my/python-lsp-test-org-block
                 "Isolate Python LSP servers by project"))
         (result
          (my/python-lsp-test-run-child
           `(progn
              (require 'package)
              (setq package-user-dir ,(my/python-lsp-test-package-dir))
              (package-initialize)
              (with-temp-buffer
                (setq-local lsp-file-watch-ignored-directories '("LOCAL"))
                (insert ,block)
                (eval-buffer)
                (require 'lsp-mode)
                (dolist (regexp my/lsp-generated-directory-watch-ignores)
                  (unless (member regexp
                                  (default-value
                                   'lsp-file-watch-ignored-directories))
                    (error "Watcher ignore missing from global default: %s"
                           regexp)))
                (unless (equal lsp-file-watch-ignored-directories '("LOCAL"))
                  (error "Local watcher override changed: %S"
                         lsp-file-watch-ignored-directories)))))))
    (ert-info ((cdr result))
      (should (= 0 (car result))))))

(ert-deftest my/python-lsp-watchers-skip-generated-hidden-trees ()
  "Generated hidden trees must be skipped without hiding normal source."
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
              (require 'lsp-mode)
              (let* ((root (make-temp-file "python-lsp-watch-" t))
                     (generated
                      (mapcar (lambda (name)
                                (let ((directory (expand-file-name name root)))
                                  (make-directory
                                   (expand-file-name "nested" directory) t)
                                  directory))
                              '(".pi-subagents" ".pi" ".ros2_ws"
                                ".superpowers" ".ruff_cache")))
                     (source (expand-file-name "src" root)))
                (unwind-protect
                    (progn
                      (make-directory source t)
                      (let ((watched
                             (mapcar #'file-truename
                                     (lsp--all-watchable-directories
                                      root lsp-file-watch-ignored-directories))))
                        (unless (member (file-truename source) watched)
                          (error "Normal source directory was not watched"))
                        (dolist (directory generated)
                          (when (member (file-truename directory) watched)
                            (error "Generated directory was watched: %s"
                                   directory)))))
                  (delete-directory root t)))))))
    (ert-info ((cdr result))
      (should (= 0 (car result))))))

(ert-deftest my/python-lsp-pyright-finds-each-project-venv ()
  "Pyright must resolve the interpreter relative to each project root."
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
              (let ((root-a (make-temp-file "pyright-project-a-" t))
                    (root-b (make-temp-file "pyright-project-b-" t)))
                (unwind-protect
                    (let (expected-a expected-b actual-a actual-b)
                      (dolist (root (list root-a root-b))
                        (let ((python (expand-file-name ".venv/bin/python" root)))
                          (make-directory (file-name-directory python) t)
                          (write-region "#!/bin/sh\nexit 0\n" nil python)
                          (set-file-modes python #o755)))
                      (setq expected-a
                            (file-truename
                             (expand-file-name ".venv/bin/python" root-a))
                            expected-b
                            (file-truename
                             (expand-file-name ".venv/bin/python" root-b)))
                      (let ((default-directory root-a))
                        (setq actual-a (file-truename
                                        (lsp-pyright-locate-python))))
                      (let ((default-directory root-b))
                        (setq actual-b (file-truename
                                        (lsp-pyright-locate-python))))
                      (unless (and (equal actual-a expected-a)
                                   (equal actual-b expected-b)
                                   (not (equal actual-a actual-b)))
                        (error "Wrong project interpreters: %S %S"
                               actual-a actual-b)))
                  (delete-directory root-a t)
                  (delete-directory root-b t)))))))
    (ert-info ((cdr result))
      (should (= 0 (car result))))))

(ert-deftest my/python-ruff-sort-imports-uses-buffer-local-executable ()
  "Import sorting must use each buffer's configured Ruff executable."
  (let* ((block (my/python-lsp-test-org-block
                 "Sort Python imports with Ruff"))
         (temporary-directory (make-temp-file "python-ruff-command-" t))
         (global-directory (expand-file-name "global/bin" temporary-directory))
         (global-ruff (expand-file-name "ruff" global-directory))
         (local-a (expand-file-name "project-a/bin/ruff" temporary-directory))
         (local-b (expand-file-name "project-b/bin/ruff" temporary-directory)))
    (unwind-protect
        (progn
          (my/python-lsp-test-write-executable global-ruff "import global_ruff")
          (my/python-lsp-test-write-executable local-a "import project_a")
          (my/python-lsp-test-write-executable local-b "import project_b")
          (let ((result
                 (my/python-lsp-test-run-child
                  `(progn
                     (with-temp-buffer
                       (insert ,block)
                       (eval-buffer))
                     (let ((exec-path (list ,global-directory))
                           (process-environment
                            (copy-sequence process-environment)))
                       (setenv "PATH" ,global-directory)
                       (dolist (case (list (cons ,local-a "import project_a\n")
                                           (cons ,local-b "import project_b\n")))
                         (with-temp-buffer
                           (python-mode)
                           (setq-local ruff-format-command (car case))
                           (insert "import unsorted\n")
                           (my/python-ruff-sort-imports)
                           (unless (string= (buffer-string) (cdr case))
                             (error "Wrong Ruff output for %s: %S"
                                    (car case) (buffer-string))))))))))
            (ert-info ((cdr result))
              (should (= 0 (car result))))))
      (delete-directory temporary-directory t))))

(ert-deftest my/python-pet-finalizes-order-sensitive-tools ()
  "Pet must finalize shell, Pyright naming, and active Flycheck locals."
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
              (setq-default python-shell-interpreter "/usr/bin/python3")
              (with-temp-buffer
                (setq-local lsp-pyright-langserver-command
                            "/tmp/project/.venv/bin/pyright")
                (setq-local lsp-pyright-python-executable-cmd
                            "/tmp/project/.venv/bin/python")
                (setq-local flycheck-mode t)
                (unless (fboundp 'my/python-pet-finalize-buffer-tools)
                  (error "Pet finalizer function is missing"))
                (let (pet-executable-requests)
                  (cl-letf
                      (((symbol-function 'pet-executable-find)
                        (lambda (executable &optional _search-globally)
                          (push executable pet-executable-requests)
                          (if (equal executable "python")
                              "/tmp/project/.venv/bin/python"
                            (error "Unexpected Pet executable: %S"
                                   executable))))
                       ((symbol-function 'pet-flycheck-toggle-local-vars)
                        (lambda ()
                          (setq-local flycheck-python-ruff-executable
                                      "/tmp/project/.venv/bin/ruff")
                          (setq-local flycheck-python-pycompile-executable
                                      "/tmp/project/.venv/bin/python"))))
                    (my/python-pet-finalize-buffer-tools))
                  (unless (and
                           (local-variable-p 'python-shell-interpreter)
                           (equal python-shell-interpreter
                                  "/tmp/project/.venv/bin/python")
                           (equal pet-executable-requests '("python")))
                    (error "Pet shell interpreter was not finalized: %S %S"
                           python-shell-interpreter pet-executable-requests)))
                (unless (equal lsp-pyright-langserver-command "pyright")
                  (error "Pyright protocol name was not restored: %S"
                         lsp-pyright-langserver-command))
                (unless (and
                         (equal lsp-pyright-python-executable-cmd
                                "/tmp/project/.venv/bin/python")
                         (local-variable-p
                          'flycheck-python-ruff-executable)
                         (local-variable-p
                          'flycheck-python-pycompile-executable)
                         (equal flycheck-python-ruff-executable
                                "/tmp/project/.venv/bin/ruff")
                         (equal flycheck-python-pycompile-executable
                                "/tmp/project/.venv/bin/python"))
                  (error "Pet interpreter/Flycheck selection changed"))
                (require 'lsp-pyright)
                (let* ((client (gethash 'pyright lsp-clients))
                       (handlers (lsp--client-notification-handlers client))
                       (dependency (gethash 'pyright lsp--dependencies))
                       (missing (make-symbol "missing")))
                  (unless client
                    (error "Pyright client was not registered"))
                  (unless (equal (plist-get (car dependency) :system)
                                 "pyright-langserver")
                    (error "Wrong Pyright dependency: %S" dependency))
                  (dolist (setting '("pyright.disableLanguageServices"
                                     "pyright.disableOrganizeImports"
                                     "pyright.disableTaggedHints"))
                    (when (eq (gethash setting lsp-client-settings missing)
                              missing)
                      (error "Missing Pyright setting: %s" setting)))
                  (dolist (notification '("pyright/beginProgress"
                                           "pyright/reportProgress"
                                           "pyright/endProgress"))
                    (when (eq (gethash notification handlers missing) missing)
                      (error "Missing Pyright handler: %s" notification)))
                  (when (seq-some
                         (lambda (name)
                           (string-prefix-p "/tmp/project/" name))
                         (append (hash-table-keys handlers)
                                 (hash-table-keys lsp-client-settings)))
                    (error "Absolute path leaked into Pyright protocol keys"))
                  (let ((buffer-file-name "/tmp/project/example.py")
                        captured-command)
                    (cl-letf (((symbol-function 'lsp-send-execute-command)
                               (lambda (command _arguments)
                                 (setq captured-command command))))
                      (lsp-pyright-organize-imports))
                    (unless (equal captured-command "pyright.organizeimports")
                      (error "Wrong organize command: %S" captured-command)))))))))
    (ert-info ((cdr result))
      (should (= 0 (car result))))))
;;; python-lsp-isolation-test.el ends here
