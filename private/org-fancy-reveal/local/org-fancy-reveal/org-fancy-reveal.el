;;; org-fancy-reveal.el --- Semantic layout helpers for org-re-reveal -*- lexical-binding: t; -*-

;; Author: Zheng Qu
;; Keywords: org, reveal, presentations
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; A tiny companion for org-re-reveal.  It keeps Org files semantic by
;; styling ordinary Org special blocks instead of requiring raw HTML blocks.
;;
;; Example:
;;
;;   #+begin_metric_cards
;;   - 6R :: *Six revolute joints.* Works for any six-axis arm.
;;   - ≤16 :: *All branches.* Classical degree bound.
;;   #+end_metric_cards
;;
;; org-re-reveal exports that block as HTML.  This package injects CSS that
;; turns the exported description list into polished metric cards.

;;; Code:

(require 'ox)
(require 'subr-x)

(defgroup org-fancy-reveal nil
  "Semantic layout helpers for org-re-reveal presentations."
  :group 'org
  :prefix "org-fancy-reveal-")

(defconst org-fancy-reveal--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing org-fancy-reveal.el.")

(defcustom org-fancy-reveal-css-file
  (expand-file-name "../../assets/org-fancy-reveal.css" org-fancy-reveal--directory)
  "CSS file injected into org-re-reveal exports."
  :type 'file
  :group 'org-fancy-reveal)

(defcustom org-fancy-reveal-python-command
  (or (executable-find "python3") (executable-find "python") "python3")
  "Python executable used for standalone fancy deck exports."
  :type 'string
  :group 'org-fancy-reveal)

(defcustom org-fancy-reveal-standalone-exporter
  (expand-file-name "../../scripts/build_interactive_deck.py" org-fancy-reveal--directory)
  "Standalone Org-to-fancy-HTML exporter script."
  :type 'file
  :group 'org-fancy-reveal)

(defun org-fancy-reveal--add-css-path (current css-path)
  "Return CURRENT extra CSS with CSS-PATH appended once.
CURRENT is the newline-separated value used by `org-re-reveal-extra-css'."
  (let* ((css-path (file-truename css-path))
         (entries (split-string (or current "") "\n" t "[[:space:]]+")))
    (unless (member css-path entries)
      (setq entries (append entries (list css-path))))
    (string-join entries "\n")))

(defun org-fancy-reveal--enable-now ()
  "Inject `org-fancy-reveal-css-file' into `org-re-reveal-extra-css'."
  (unless (file-readable-p org-fancy-reveal-css-file)
    (user-error "org-fancy-reveal CSS file is missing: %s" org-fancy-reveal-css-file))
  (defvar org-re-reveal-extra-css "")
  (setq org-re-reveal-extra-css
        (org-fancy-reveal--add-css-path org-re-reveal-extra-css org-fancy-reveal-css-file)))

;;;###autoload
(defun org-fancy-reveal-enable ()
  "Enable org-fancy-reveal integration after org-re-reveal loads."
  (interactive)
  (if (featurep 'org-re-reveal)
      (org-fancy-reveal--enable-now)
    (with-eval-after-load 'org-re-reveal
      (org-fancy-reveal--enable-now))))

(defun org-fancy-reveal--insert-lines (&rest lines)
  "Insert LINES followed by newlines."
  (insert (mapconcat #'identity lines "\n") "\n"))

(defun org-fancy-reveal--output-file (&optional output-file)
  "Return OUTPUT-FILE or the default HTML path for the current Org buffer."
  (or output-file
      (unless buffer-file-name
        (user-error "Current buffer is not visiting a file"))
      (concat (file-name-sans-extension buffer-file-name) ".html")))

;;;###autoload
(defun org-fancy-reveal-export-to-html (&optional async subtreep visible-only body-only ext-plist)
  "Export the current Org file to standalone fancy HTML.
This command is separate from `org-re-reveal-export-to-html': it runs the
standalone semantic deck exporter.  ASYNC, SUBTREEP, VISIBLE-ONLY and
BODY-ONLY are accepted for Org export dispatcher compatibility and are
currently ignored.  EXT-PLIST may contain `:output-file'."
  (interactive)
  (ignore async subtreep visible-only body-only)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (unless (file-readable-p org-fancy-reveal-standalone-exporter)
    (user-error "Fancy reveal exporter is missing: %s" org-fancy-reveal-standalone-exporter))
  (unless (executable-find org-fancy-reveal-python-command)
    (user-error "Python executable not found: %s" org-fancy-reveal-python-command))
  (when (and (called-interactively-p 'interactive)
             (buffer-modified-p)
             (y-or-n-p "Save buffer before fancy export? "))
    (save-buffer))
  (let* ((source-file (file-truename buffer-file-name))
         (output-file (plist-get ext-plist :output-file))
         (target-file (file-truename (org-fancy-reveal--output-file output-file)))
         (log-buffer (get-buffer-create "*org-fancy-reveal-export*")))
    (with-current-buffer log-buffer
      (erase-buffer))
    (let ((exit-code
           (call-process org-fancy-reveal-python-command nil log-buffer nil
                         org-fancy-reveal-standalone-exporter source-file target-file)))
      (unless (zerop exit-code)
        (display-buffer log-buffer)
        (user-error "Fancy reveal export failed with exit code %s" exit-code)))
    (message "Exported fancy reveal deck: %s" target-file)
    target-file))

;;;###autoload
(defun org-fancy-reveal-export-to-html-and-browse (&optional async subtreep visible-only body-only ext-plist)
  "Export the current Org file to standalone fancy HTML and open it.
Arguments are accepted for Org export dispatcher compatibility; see
`org-fancy-reveal-export-to-html'."
  (interactive)
  (let ((target-file (org-fancy-reveal-export-to-html async subtreep visible-only body-only ext-plist)))
    (browse-url-of-file target-file)
    target-file))

(defun org-fancy-reveal--define-export-backend ()
  "Register an Org export dispatcher entry for standalone fancy decks."
  (org-export-define-backend 'fancy-reveal nil
    :menu-entry
    '(?F "Export to standalone fancy HTML"
         ((?f "To file" org-fancy-reveal-export-to-html)
          (?b "To file and browse" org-fancy-reveal-export-to-html-and-browse)))))

(org-fancy-reveal--define-export-backend)

;;;###autoload
(defun org-fancy-reveal-insert-metric-cards ()
  "Insert a semantic metric card block."
  (interactive)
  (org-fancy-reveal--insert-lines
   "#+begin_metric_cards"
   "- 6R :: *Six revolute joints.* Short explanation."
   "- ≤16 :: *All branches.* Short explanation."
   "#+end_metric_cards"))

;;;###autoload
(defun org-fancy-reveal-insert-cards ()
  "Insert a semantic cards block."
  (interactive)
  (org-fancy-reveal--insert-lines
   "#+begin_cards"
   "- First card ::"
   "  - Main point."
   "  - Supporting point."
   "- Second card ::"
   "  - Main point."
   "  - Supporting point."
   "#+end_cards"))

;;;###autoload
(defun org-fancy-reveal-insert-columns ()
  "Insert semantic two-column special blocks."
  (interactive)
  (org-fancy-reveal--insert-lines
   "#+begin_columns"
   "#+begin_column"
   "Left column content."
   "#+end_column"
   "#+begin_column"
   "Right column content."
   "#+end_column"
   "#+end_columns"))

(provide 'org-fancy-reveal)
;;; org-fancy-reveal.el ends here
