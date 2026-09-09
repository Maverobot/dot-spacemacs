;;; ccls-index-recovery-test.el --- ccls open recovery regressions -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst my/ccls-test-root
  (file-name-directory
   (directory-file-name (file-name-directory (or load-file-name default-directory)))))
(defconst my/ccls-test-file (or load-file-name buffer-file-name))

(defun my/ccls-test-block ()
  "Extract the canonical ccls configuration, without enabling lexical binding."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "spacemacs.org" my/ccls-test-root))
    (goto-char (point-min))
    (re-search-forward "^\\*+ ccls$")
    (re-search-forward "^#\\+BEGIN_SRC emacs-lisp.*\n")
    (let ((start (point)))
      (re-search-forward "^#\\+END_SRC$")
      (buffer-substring-no-properties start (match-beginning 0)))))

(defun my/ccls-test-child (scenario compiled)
  "Run SCENARIO in clean Emacs with interpreted or COMPILED configuration."
  (let* ((directory (make-temp-file "ccls-index-test-" t))
         (config (expand-file-name "config.el" directory))
         (script (expand-file-name "run.el" directory)))
    (unwind-protect
        (progn
          (write-region (my/ccls-test-block) nil config nil 'silent)
          (write-region
           (prin1-to-string
            `(progn
               (require 'package)
               (setq package-user-dir
                     ,(or (getenv "SPACEMACS_TEST_PACKAGE_DIR")
                          (expand-file-name "elpa/30.2/develop" user-emacs-directory)))
               (package-initialize)
               ,@(when compiled `((byte-compile-file ,config)))
               (load ,(if compiled (concat config "c") config) nil t)
               (require 'lsp-mode)
               (load ,my/ccls-test-file nil t)
               (funcall ',scenario)))
           nil script nil 'silent)
          (with-temp-buffer
            (let ((status (call-process
                           (expand-file-name invocation-name invocation-directory)
                           nil t nil "-Q" "--batch" "-l" script)))
              (ert-info ((format "Compiled: %S\n%s" compiled (buffer-string)))
                (should (equal status 0))))))
      (delete-directory directory t))))

(defvar my/ccls-test-requests nil)
(defvar my/ccls-test-notifications nil)
(defvar my/ccls-test-errors nil)

(defun my/ccls-test-request (method params callback &rest options)
  (push (list :workspace lsp--cur-workspace :method method :params params
              :success callback :error (plist-get options :error-handler))
        my/ccls-test-requests))

(defun my/ccls-test-notify (method params)
  (push (list lsp--cur-workspace method params) my/ccls-test-notifications))

(defun my/ccls-test-report-error (error)
  (push error my/ccls-test-errors))

(defun my/ccls-test-error (code message)
  (lsp-make-json-error :code code :message message))

(defun my/ccls-test-open (workspace &optional duplicate)
  (let ((lsp--cur-workspace workspace))
    (unless duplicate (run-hooks 'lsp-before-open-hook))
    (run-hooks 'lsp-ccls-after-open-hook)))

(defun my/ccls-test-with-document (scenario)
  "Exercise SCENARIO with real workspace objects and deferred probe callbacks."
  (let* ((process (make-pipe-process :name "ccls-test" :noquery t))
         (buffer (generate-new-buffer " *ccls-test*"))
         (workspace (make-lsp--workspace
                     :client (make-lsp-client :server-id 'ccls)
                     :status 'initialized :proc process :buffers (list buffer)))
         (other (make-lsp--workspace :client (make-lsp-client :server-id 'clangd)))
         (my/ccls-test-requests nil)
         (my/ccls-test-notifications nil)
         (my/ccls-test-errors nil))
    (unwind-protect
        (cl-letf (((symbol-function 'lsp-request-async) #'my/ccls-test-request)
                  ((symbol-function 'lsp-notify) #'my/ccls-test-notify)
                  ((symbol-function 'lsp--create-default-error-handler)
                   (lambda (_) #'my/ccls-test-report-error)))
          (with-current-buffer buffer
            (setq buffer-file-name "/unavailable/project/header.hpp")
            (insert "struct Unsaved {};\n")
            (setq-local lsp--buffer-workspaces (list workspace other))
            (funcall scenario workspace other)))
      (when (buffer-live-p buffer) (kill-buffer buffer))
      (delete-process process))))

(ert-deftest my/ccls-index-recovers-only-exact-error-once ()
  "Only ccls's exact error sends one notification; success and other errors do not."
  (dolist (compiled '(nil t))
    (my/ccls-test-child
     '(lambda ()
       (my/ccls-test-with-document
        (lambda (workspace other)
          (let ((text (buffer-string)) (tick (buffer-chars-modified-tick)))
            (my/ccls-test-open other)
            (should-not my/ccls-test-requests)
            (dolist (outcome '(success empty wrong-code wrong-message missing))
              (my/ccls-test-open workspace)
              (let ((request (car my/ccls-test-requests)))
                (should (eq workspace (plist-get request :workspace)))
                (should (equal "textDocument/documentSymbol" (plist-get request :method)))
                (pcase outcome
                  ('success (funcall (plist-get request :success) '(symbols)))
                  ('empty (funcall (plist-get request :success) nil))
                  (_ (funcall (plist-get request :error)
                              (my/ccls-test-error
                               (if (eq outcome 'wrong-code) -32601 -32600)
                               (if (eq outcome 'wrong-message) "other error" "not indexed")))))
                (unless (eq outcome 'missing)
                  (should-not my/ccls-test-notifications))))
            (should (= 2 (length my/ccls-test-errors)))
            (let ((request (car my/ccls-test-requests)))
              (my/ccls-test-open workspace t)
              (should (= 5 (length my/ccls-test-requests)))
              (funcall (plist-get request :error) (my/ccls-test-error -32600 "not indexed"))
              (should (equal my/ccls-test-notifications
                             (list (list workspace "textDocument/didSave"
                                         (plist-get request :params))))))
            (should (equal text (buffer-string)))
            (should (= tick (buffer-chars-modified-tick)))
            (should (buffer-modified-p))))))
     compiled)))

(ert-deftest my/ccls-index-rejects-stale-callbacks ()
  "Killed, renamed, closed, disconnected, restarted, and reopened documents are stale."
  (dolist (compiled '(nil t))
    (my/ccls-test-child
     '(lambda ()
       (dolist (change '(kill rename rename-back close disconnect restart dead-process replaced-process reopen))
         (my/ccls-test-with-document
          (lambda (workspace _other)
            (my/ccls-test-open workspace)
            (let ((callback (plist-get (car my/ccls-test-requests) :error)))
              (pcase change
                ('kill (kill-buffer (current-buffer)))
                ('rename (setq buffer-file-name "/unavailable/project/renamed.hpp"))
                ('rename-back (run-hooks 'after-set-visited-file-name-hook))
                ('close (setf (lsp--workspace-buffers workspace) nil))
                ('disconnect (setq lsp--buffer-workspaces nil))
                ('restart (setf (lsp--workspace-status workspace) 'starting))
                ('dead-process (delete-process (lsp--workspace-proc workspace)))
                ('replaced-process (setf (lsp--workspace-proc workspace) nil))
                ('reopen (my/ccls-test-open workspace)))
              ;; Deliberately invoke even after kill: lsp-mode's error callbacks
              ;; do not inherit its success callback's buffer-liveness wrapper.
              (with-temp-buffer
                (funcall callback (my/ccls-test-error -32600 "not indexed")))
              (should-not my/ccls-test-notifications)
              (should-not my/ccls-test-errors)
              (when (eq change 'reopen)
                (funcall (plist-get (car my/ccls-test-requests) :error)
                         (my/ccls-test-error -32600 "not indexed"))
                (should (= 1 (length my/ccls-test-notifications)))))))))
     compiled)))

(ert-deftest my/ccls-index-keeps-concurrent-workspaces-independent ()
  "Each ccls workspace owns its request even when responses arrive elsewhere."
  (dolist (compiled '(nil t))
    (my/ccls-test-child
     '(lambda ()
       (my/ccls-test-with-document
        (lambda (workspace other)
          (setf (lsp--workspace-client other) (make-lsp-client :server-id 'ccls)
                (lsp--workspace-status other) 'initialized
                (lsp--workspace-proc other) (lsp--workspace-proc workspace)
                (lsp--workspace-buffers other) (list (current-buffer)))
          (my/ccls-test-open workspace)
          (my/ccls-test-open other)
          (should (= 2 (length my/ccls-test-requests)))
          (dolist (request my/ccls-test-requests)
            (with-temp-buffer
              (let ((lsp--cur-workspace other))
                (funcall (plist-get request :error)
                         (my/ccls-test-error -32600 "not indexed"))))
            (should (eq (caar my/ccls-test-notifications)
                        (plist-get request :workspace)))))))
     compiled)))

(defun my/ccls-test-repeated-renames ()
  "Keep real rename, disconnect, and managed-mode hooks with controlled transport."
  (let* ((directory (make-temp-file "ccls-rename-test-" t))
         (header (expand-file-name "header.hpp" directory))
         (alias (expand-file-name "alias.hpp" directory))
         (disk-text "struct OnDisk {};\n")
         (lsp-auto-configure nil)
         (lsp-auto-touch-files nil))
    (unwind-protect
        (progn
          (dolist (file (list header alias))
            (write-region disk-text nil file nil 'silent))
          (my/ccls-test-with-document
           (lambda (workspace _other)
             (set-visited-file-name header t)
             (setq-local lsp--buffer-language "cpp")
             ;; Only server selection is controlled: reconnect through the real
             ;; didOpen path, which reinstalls lsp-managed-mode's rename hook.
             (cl-letf (((symbol-function 'lsp)
                        (lambda (&optional _arg)
                          (setq-local lsp--buffer-workspaces (list workspace))
                          (let ((lsp--cur-workspace workspace))
                            (lsp--text-document-did-open)))))
               (unwind-protect
                   (progn
                     (lsp)
                     (set-visited-file-name alias t)
                     (set-visited-file-name header t)
                     (should (= 3 (length my/ccls-test-requests)))
                     ;; set-visited-file-name itself marks the buffer modified.
                     ;; Check both states after renaming, around probe replies.
                     (dolist (modified '(nil t))
                       (set-buffer-modified-p modified)
                       (let ((text (buffer-string))
                             (tick (buffer-chars-modified-tick)))
                         (dolist (stale (cdr my/ccls-test-requests))
                           (funcall (plist-get stale :error)
                                    (my/ccls-test-error -32600 "not indexed")))
                         (should-not
                          (seq-find (lambda (event)
                                      (equal (cadr event) "textDocument/didSave"))
                                    my/ccls-test-notifications))
                         (let ((fresh (car my/ccls-test-requests)))
                           (funcall (plist-get fresh :error)
                                    (my/ccls-test-error -32600 "not indexed"))
                           (should
                            (equal
                             (seq-filter (lambda (event)
                                           (equal (cadr event) "textDocument/didSave"))
                                         my/ccls-test-notifications)
                             (list (list workspace "textDocument/didSave"
                                         (plist-get fresh :params))))))
                         (should-not my/ccls-test-errors)
                         (should (equal text (buffer-string)))
                         (should (= tick (buffer-chars-modified-tick)))
                         (should (eq modified (buffer-modified-p)))
                         (dolist (file (list header alias))
                           (should (equal disk-text
                                          (with-temp-buffer
                                            (insert-file-contents file)
                                            (buffer-string))))))
                       ;; Start a fresh round trip for the modified-buffer case.
                       (unless modified
                         (setq my/ccls-test-notifications nil)
                         (set-visited-file-name alias t)
                         (set-visited-file-name header t))))
                 (lsp-disconnect))))))
      (delete-directory directory t))))

(ert-deftest my/ccls-index-recovers-after-repeated-renames ()
  "Repeated real renames recover only the fresh document without saving edits."
  (dolist (compiled '(nil t))
    (my/ccls-test-child 'my/ccls-test-repeated-renames compiled)))

;;; ccls-index-recovery-test.el ends here
