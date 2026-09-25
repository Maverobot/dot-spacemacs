;;; scad-upstream-test.el --- Managed OpenSCAD workflow tests -*- lexical-binding: t; -*-

;; Run with package-initialize for the active profile before loading this file.
;; These integration tests require OpenSCAD (and a working PNG render backend).
(require 'ert)
(require 'cl-lib)
(require 'scad-mode)
(require 'flymake)
(require 'use-package)
(require 'ranger)
(require 'evil)

(defconst scad-upstream-test-root
  (file-name-directory (directory-file-name
                        (file-name-directory (or load-file-name buffer-file-name)))))

(defun scad-upstream-test-load-block (heading)
  "Evaluate only the configuration block under HEADING."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "spacemacs.org" scad-upstream-test-root))
    (goto-char (point-min))
    (re-search-forward (concat "^\\*+ " (regexp-quote heading) "$"))
    (re-search-forward "^#\\+BEGIN_SRC emacs-lisp.*\n")
    (let ((start (point)))
      (re-search-forward "^#\\+END_SRC")
      (eval-region start (match-beginning 0)))))

(dolist (heading '("scad-mode" "STL review" "Ranger STL preview"))
  (scad-upstream-test-load-block heading))

(defun scad-upstream-test-write (file text)
  "Write TEXT to FILE without visiting it."
  (write-region text nil file nil 'silent))

(defun scad-upstream-test-wait (process &optional exit-status)
  "Wait for PROCESS and its sentinel, expecting EXIT-STATUS (default zero)."
  (let ((deadline (+ (float-time) 20)))
    (while (and (process-live-p process) (< (float-time) deadline))
      (accept-process-output process 0.05))
    (accept-process-output process 0.05)
    (should-not (process-live-p process))
    (should (= (or exit-status 0) (process-exit-status process)))))

(defun scad-upstream-test-image (preview)
  "Wait for PREVIEW's real render and return its PNG bytes."
  (with-current-buffer preview
    (should (processp scad--preview-proc))
    (scad-upstream-test-wait scad--preview-proc)
    (should (equal scad--preview-mode-status "Done"))
    (should (equal (plist-get (cdr (get-text-property (point-min) 'display)) :file)
                   scad--preview-image))
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (insert-file-contents-literally (buffer-local-value 'scad--preview-image preview))
      (should (string-prefix-p "\211PNG" (buffer-string)))
      (buffer-string))))

(defmacro scad-upstream-test-with-fixture (&rest body)
  "Run BODY with isolated files, executable path, buffers and render settings."
  (declare (indent 0) (debug t))
  `(let* ((directory (make-temp-file "scad upstream space " t))
          (temporary-file-directory (file-name-as-directory directory))
          (default-directory temporary-file-directory)
          (bin (expand-file-name "bin space" directory))
          (openscad (executable-find "openscad"))
          (exec-path (cons bin exec-path))
          (process-environment (copy-sequence process-environment))
          (find-file-hook nil)
          (scad-preview-refresh nil)
          (scad-preview-colorscheme "Tomorrow")
          (scad-extra-args '("--viewall" "--autocenter"))
          (buffers-before (buffer-list)))
     (skip-unless openscad)
     (make-directory bin)
     (make-symbolic-link openscad (expand-file-name "openscad" bin))
     (setenv "QT_QPA_PLATFORM" "offscreen")
     (unwind-protect
         (save-window-excursion ,@body)
       (dolist (buffer (buffer-list))
         (unless (memq buffer buffers-before)
           (when (buffer-live-p buffer)
             (with-current-buffer buffer (set-buffer-modified-p nil))
             (kill-buffer buffer))))
       (delete-directory directory t))))

(defun scad-upstream-test-mesh (source dimensions)
  "Export a real STL to SOURCE with cube DIMENSIONS."
  (let ((model (expand-file-name "mesh.scad" temporary-file-directory)))
    (scad-upstream-test-write model (format "cube(%s);\n" dimensions))
    (should (zerop (call-process (executable-find "openscad") nil nil nil
                                "-o" source model)))))

(ert-deftest scad-upstream-standalone-disk-rerender-and-cleanup ()
  "An STL visit preserves bytes/selection, rerenders disk changes, and cleans up."
  (scad-upstream-test-with-fixture
    (let* ((source (expand-file-name "part \\\"quoted\\\".stl" directory))
           (selected (selected-window))
           (selected-buffer (window-buffer selected))
           (normal-map (copy-keymap scad-preview-mode-map))
           source-buffer preview adapter image png)
      (scad-upstream-test-mesh source "[10,10,10]")
      (let ((bytes (with-temp-buffer
                     (insert-file-contents-literally source) (buffer-string))))
        (setq source-buffer (find-file-noselect source))
        (should (eq selected (selected-window)))
        (should (eq selected-buffer (window-buffer selected)))
        (with-current-buffer source-buffer
          (should (derived-mode-p 'my/stl-review-mode))
          (should buffer-read-only)
          (should (equal bytes (buffer-string)))
          (setq preview my/stl-review-preview-buffer
                adapter my/stl-review-adapter-buffer))
        (setq png (scad-upstream-test-image preview))
        (should (equal bytes (with-temp-buffer
                               (insert-file-contents-literally source) (buffer-string)))))
      (with-current-buffer preview
        (should (eq (key-binding (kbd "g")) #'my/stl-review-rerender))
        (should (eq (evil-lookup-key (evil-state-property 'normal :local-keymap t)
                                   (kbd "g")) #'my/stl-review-rerender))
        (setq image scad--preview-image)
        (scad-upstream-test-mesh source "[10,30,5]")
        (call-interactively (key-binding (kbd "g"))))
      (should-not (equal png (scad-upstream-test-image preview)))
      (should-not (file-exists-p image))
      (should (equal normal-map scad-preview-mode-map))
      (setq image (buffer-local-value 'scad--preview-image preview))
      (kill-buffer source-buffer)
      (should-not (buffer-live-p preview))
      (should-not (buffer-live-p adapter))
      (should-not (file-exists-p image))
      (should-not (directory-files directory nil "^scad-preview-")))))

(ert-deftest scad-upstream-ranger-passive-render-reuse-and-close ()
  "Real upstream renders remain passive and are owned by Ranger."
  (scad-upstream-test-with-fixture
    (let* ((source (expand-file-name "part.stl" directory))
           (other (expand-file-name "other.stl" directory))
           (owner (generate-new-buffer " *scad ranger owner*"))
           (selected (selected-window))
           (windows (window-list)) preview adapter image)
      (scad-upstream-test-mesh source "10")
      (copy-file source other)
      (with-current-buffer owner
        (dired-mode directory)
        ;; Ranger's mode is normally set by its window-layout entry command.
        (setq major-mode 'ranger-mode)
        (setq preview (ranger-preview-buffer source)
              adapter my/stl-review-adapter-buffer)
        (scad-upstream-test-image preview)
        (should (eq selected (selected-window)))
        (should (equal windows (window-list)))
        (should-not (get-file-buffer source))
        (should (eq preview (ranger-preview-buffer source)))
        (setq image (buffer-local-value 'scad--preview-image preview))
        (ranger-preview-buffer other)
        (should-not (buffer-live-p preview))
        (should-not (buffer-live-p adapter))
        (should-not (file-exists-p image))
        (setq preview my/stl-review-preview-buffer
              adapter my/stl-review-adapter-buffer)
        (scad-upstream-test-image preview)
        ;; Closing a preview clears ownership without closing Ranger.
        (kill-buffer preview)
        (should-not my/stl-review-preview-buffer)
        (should-not (buffer-live-p adapter))
        (setq preview (ranger-preview-buffer source)
              adapter my/stl-review-adapter-buffer)
        ;; Closing an owner while rendering also cleans process input/output.
        (let ((process (buffer-local-value 'scad--preview-proc preview)))
          (kill-buffer owner)
          (accept-process-output process 0.05)
          (should-not (process-live-p process))))
      (should-not (buffer-live-p preview))
      (should-not (buffer-live-p adapter))
      (should-not (directory-files directory nil "^scad-preview-")))))

(ert-deftest scad-upstream-relative-libraries-flymake-and-camera ()
  "Relative use/include and existing OPENSCADPATH work in real render/Flymake."
  (scad-upstream-test-with-fixture
    (let* ((library-dir (expand-file-name "search path" directory))
           (source (expand-file-name "main.scad" directory))
           source-buffer preview)
      (make-directory library-dir)
      (setenv "OPENSCADPATH" library-dir)
      (scad-upstream-test-write (expand-file-name "external.scad" library-dir)
                                "module external() { cube(10); }\n")
      (scad-upstream-test-write (expand-file-name "local.scad" directory)
                                "use <external.scad>\nmodule local() { external(); }\n")
      (scad-upstream-test-write (expand-file-name "values.scad" directory) "size = 10;\n")
      (scad-upstream-test-write source
                                "include <values.scad>\nuse <local.scad>\nuse <external.scad>\nassert(size == 10); local();\n")
      (setq source-buffer (find-file-noselect source))
      (with-current-buffer source-buffer
        (should (derived-mode-p 'scad-mode))
        (should flymake-mode)
        (should (memq #'scad-flymake flymake-diagnostic-functions))
        (setq-local scad-command (executable-find "openscad"))
        (let ((reported :pending))
          (scad-flymake (lambda (diagnostics &rest _) (setq reported diagnostics)))
          (scad-upstream-test-wait scad--flymake-proc)
          (should (null reported)))
        ;; A parser error in the relative include proves Flymake reads it.
        (scad-upstream-test-write (expand-file-name "values.scad" directory) "size = ;\n")
        (let ((reported :pending))
          (scad-flymake (lambda (diagnostics &rest _) (setq reported diagnostics)))
          (scad-upstream-test-wait scad--flymake-proc 1)
          (should (listp reported))
          (should (eq (flymake-diagnostic-type (car reported)) :error))))
      (scad-upstream-test-write (expand-file-name "values.scad" directory) "size = 10;\n")
      (with-current-buffer source-buffer
        (let ((scad-command (executable-find "openscad"))) (scad-preview))
        (setq preview scad--preview-buffer))
      (scad-upstream-test-image preview)
      (should (equal (getenv "OPENSCADPATH") library-dir))
      (with-current-buffer preview
        (dolist (case '(("C-h" 5 -20) ("C-l" 5 20) ("C-k" 3 -20) ("C-j" 3 20)
                        ("M-h" 6 100) ("M-l" 6 -100) ("M-k" 2 10) ("M-j" 2 -10)))
          (let* ((index (nth 1 case)) (before (nth index scad-preview-camera)))
            (call-interactively (key-binding (kbd (car case))))
            (should (= (nth index scad-preview-camera) (+ before (nth 2 case)))))
          (scad-upstream-test-image preview)))
      (kill-buffer preview))))

(ert-deftest scad-upstream-ranger-entry-transitions-and-errors ()
  "Real Dired entry changes clean previews, including skipped entries/errors."
  (scad-upstream-test-with-fixture
    (let* ((source (expand-file-name "part.stl" directory))
           (text (expand-file-name "notes.txt" directory))
           (excluded (expand-file-name "ignored.skip" directory))
           (subdir (expand-file-name "subdir" directory))
           (ranger-excluded-extensions '("skip"))
           (special-map (copy-keymap special-mode-map))
           owner preview adapter)
      (scad-upstream-test-mesh source "10")
      (scad-upstream-test-write text "notes\n")
      (scad-upstream-test-write excluded "excluded\n")
      (make-directory subdir)
      (setq owner (dired-noselect directory))
      (with-current-buffer owner
        (setq major-mode 'ranger-mode)
        (dolist (entry (list text excluded subdir))
          (should (dired-goto-file source))
          (setq preview (ranger-preview-buffer source)
                adapter my/stl-review-adapter-buffer)
          (scad-upstream-test-image preview)
          (run-hooks 'post-command-hook)
          (should (buffer-live-p preview))
          (should (dired-goto-file entry))
          (run-hooks 'post-command-hook)
          (should-not (buffer-live-p preview))
          (should-not (buffer-live-p adapter))
          ;; Real setup still accepts the cleaned owner when rendering is off.
          (let ((ranger-preview-file nil)) (ranger-setup-preview)))
        (should (dired-goto-file source))
        (let ((exec-path nil))
          (setq preview (ranger-preview-buffer source)))
        (should-not (get-file-buffer source))
        (with-current-buffer preview
          (should buffer-read-only)
          (should (string-match-p "OpenSCAD is not executable" (buffer-string)))
          (local-set-key (kbd "<mouse-1>") #'ignore))
        (should (equal special-map special-mode-map))
        (should (dired-goto-file excluded))
        (run-hooks 'post-command-hook)
        (should-not (buffer-live-p preview))
        (should-not my/stl-review-preview-buffer)))))

(ert-deftest scad-upstream-close-after-render-before-sentinel ()
  "Closing an owner after output reaches disk must not leave a late image."
  (scad-upstream-test-with-fixture
    (let* ((source (expand-file-name "part.stl" directory))
           (owner (generate-new-buffer " *scad late close owner*"))
           preview process output adapter)
      (scad-upstream-test-mesh source "10")
      (with-current-buffer owner
        (dired-mode directory)
        (setq major-mode 'ranger-mode
              preview (ranger-preview-buffer source)
              adapter my/stl-review-adapter-buffer))
      (setq process (buffer-local-value 'scad--preview-proc preview)
            output (cadr (member "-o" (process-command process))))
      ;; Poll the real output without yielding to Emacs' process dispatch.
      ;; This targets the interval before the completion sentinel runs.
      (let ((deadline (+ (float-time) 20)))
        (while (and (< (float-time) deadline)
                    (not (and (file-exists-p output)
                              (> (file-attribute-size (file-attributes output)) 0))))))
      (should (file-exists-p output))
      (should (> (file-attribute-size (file-attributes output)) 0))
      (should-not (buffer-local-value 'scad--preview-image preview))
      (kill-buffer owner)
      (accept-process-output process 0.05)
      (should-not (process-live-p process))
      (should-not (buffer-live-p preview))
      (should-not (buffer-live-p adapter))
      (should-not (directory-files directory nil "^scad-preview-")))))

(defun scad-upstream-test-break-launcher (bin)
  "Replace the fixture's launcher with an executable having a missing interpreter."
  (let ((launcher (expand-file-name "openscad" bin)))
    (delete-file launcher)
    (scad-upstream-test-write launcher "#!/nonexistent/scad-test-interpreter\n")
    (set-file-modes launcher #o755)
    launcher))

(ert-deftest scad-upstream-broken-launcher-preview-cleanup ()
  "A synchronous process failure leaves a readable error, not preview artifacts."
  (scad-upstream-test-with-fixture
    (let* ((source (expand-file-name "part.stl" directory))
           (owner (generate-new-buffer " *scad broken launcher owner*"))
           preview)
      (scad-upstream-test-mesh source "10")
      (scad-upstream-test-break-launcher bin)
      (with-current-buffer owner
        (dired-mode directory)
        (setq major-mode 'ranger-mode
              preview (ranger-preview-buffer source)))
      (with-current-buffer preview
        (should buffer-read-only)
        (should (string-match-p "STL review unavailable:" (buffer-string)))
        (should (string-match-p "No such file or directory" (buffer-string))))
      (should-not (get-file-buffer source))
      (should-not (directory-files directory nil "^scad-preview-"))
      (kill-buffer owner)
      (should-not (buffer-live-p preview)))))

(ert-deftest scad-upstream-broken-launcher-flymake-cleanup ()
  "A synchronous Flymake failure must release its input and private output buffer."
  (scad-upstream-test-with-fixture
    (let* ((scad-command (scad-upstream-test-break-launcher bin))
           (buffers-before-start (buffer-list)))
      (with-temp-buffer
        (insert "cube(10);\n")
        (scad-mode)
        (flymake-mode -1)
        (should-error (scad-flymake #'ignore) :type 'file-missing))
      (should-not (directory-files directory nil "^scad-flymake-"))
      (should-not
       (cl-find-if
        (lambda (buffer) (string-prefix-p " *scad-flymake" (buffer-name buffer)))
        (cl-set-difference (buffer-list) buffers-before-start))))))

(provide 'scad-upstream-test)
;;; scad-upstream-test.el ends here
