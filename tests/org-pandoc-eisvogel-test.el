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

(defconst my/org-pandoc-test-fixture
  "#+TITLE: Fixture Doc
#+AUTHOR: Fixture Author
#+OPTIONS: toc:nil num:nil

* Section Alpha
alpha-visible-text
** Section Beta
beta-hidden-text
* Section Gamma
gamma-other-text and an arrow →
中文段落:先弄清他们想解决哪一层的问题。

#+begin_src sh
  ls → /opt
#+end_src

#+begin_src typescript
const answer: number = 42;
#+end_src
"
  "Org document exercising headings, folding, CJK text and code blocks.")

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

(with-temp-buffer
  (insert (my/org-pandoc-test-config-block))
  (eval-buffer))

(defun my/org-pandoc-test-in-buffer (body)
  "Visit a temporary file holding `my/org-pandoc-test-fixture' and run BODY.
BODY runs in the fixture's Org buffer with point at the beginning of the file."
  (let* ((directory (make-temp-file "org-pandoc-fixture-" t))
         (default-directory (file-name-as-directory directory))
         (input-file (expand-file-name "fixture.org" directory))
         buffer)
    (unwind-protect
        (progn
          (with-temp-file input-file (insert my/org-pandoc-test-fixture))
          (setq buffer (find-file-noselect input-file))
          (with-current-buffer buffer
            (org-mode)
            (goto-char (point-min))
            (funcall body)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (delete-directory directory t))))

(defun my/org-pandoc-test-pdf-text (pdf-file)
  "Return the text layer of PDF-FILE, or nil when pdftotext is unavailable."
  (when (executable-find "pdftotext")
    (with-temp-buffer
      (when (zerop (call-process "pdftotext" nil (list (current-buffer) nil)
                                nil pdf-file "-"))
        (buffer-string)))))

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
                         0))
                      ;; Font probing must not depend on the host fontconfig setup.
                      ((symbol-function 'my/org-pandoc-eisvogel--font-available-p)
                       (lambda (_font) t)))
              (my/org-pandoc-eisvogel-export output-file nil nil nil nil nil)))
          pandoc-arguments)
      (when (buffer-live-p input-buffer)
        (kill-buffer input-buffer))
      (when-let* ((output-buffer (get-buffer " *org-pandoc-eisvogel*")))
        (kill-buffer output-buffer))
      (delete-directory temporary-directory t))))

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

(ert-deftest my/org-pandoc-eisvogel-exports-renamed-source-languages ()
  "Org source blocks whose language Pandoc renames must still export to PDF.

Pandoc's Org reader stores the pre-rename language in an `org-language'
key-value attribute.  The --listings path used to forward it into the
`\\begin{lstlisting}' optional argument, where listings knows no such key and
XeTeX aborted with \"Package keyval Error: org-language undefined\"."
  (skip-unless (and (executable-find "pandoc")
                   (executable-find "xelatex")))
  (let ((temporary-directory (make-temp-file "org-pandoc-languages-" t)))
    (unwind-protect
        (dolist (lang '("sh" "emacs-lisp" "js"))
          (let ((input-file (expand-file-name (format "%s.org" lang)
                                             temporary-directory))
                (output-file (expand-file-name (format "%s.pdf" lang)
                                             temporary-directory)))
            (with-temp-file input-file
              (insert (format "#+OPTIONS: toc:nil num:nil\n#+begin_src %s\nputs 1\n#+end_src\n"
                             lang)))
            (let ((input-buffer (find-file-noselect input-file)))
              (unwind-protect
                  (with-current-buffer input-buffer
                    (org-mode)
                    (my/org-pandoc-eisvogel-export output-file nil nil nil nil nil))
                (when (buffer-live-p input-buffer)
                  (kill-buffer input-buffer)))
              (should (file-exists-p output-file))
              (should (> (nth 7 (file-attributes output-file)) 0)))))
      (delete-directory temporary-directory t))))

(ert-deftest my/org-pandoc-eisvogel-renders-cjk-text ()
  "Chinese text must actually reach the PDF, not be silently dropped."
  (skip-unless (and (executable-find "pandoc")
                   (executable-find "xelatex")
                   (executable-find "pdftotext")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (let ((output-file (call-interactively #'my/org-pandoc-eisvogel-export)))
       (should (file-exists-p output-file))
       (let ((text (my/org-pandoc-test-pdf-text output-file)))
         (should text)
         (should (string-match-p "先弄清他们想解决哪一层的问题" text))
         ;; XeTeX warns instead of failing when a glyph is unavailable.
         (should-not (string-match-p "Missing character"
                                    (with-current-buffer " *org-pandoc-eisvogel*"
                                      (buffer-string)))))))))

(ert-deftest my/org-pandoc-eisvogel-subtree-export-scopes-and-names ()
  "A subtree export contains only that subtree and is named after its heading."
  (skip-unless (and (executable-find "pandoc")
                   (executable-find "xelatex")
                   (executable-find "pdftotext")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (re-search-forward "^\\* Section Gamma$")
     (let ((output-file (my/org-pandoc-eisvogel-export nil nil t nil nil nil)))
       (should (file-exists-p output-file))
       (should (string-suffix-p "-Section-Gamma.pdf" output-file))
       (let ((text (my/org-pandoc-test-pdf-text output-file)))
         (should text)
         (should (string-match-p "gamma-other-text" text))
         (should-not (string-match-p "alpha-visible-text" text)))))))

(ert-deftest my/org-pandoc-eisvogel-visible-only-drops-folded-content ()
  "VISIBLE-ONLY must skip folded sections, like Org's own exporters."
  (skip-unless (and (executable-find "pandoc")
                   (executable-find "xelatex")
                   (executable-find "pdftotext")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (goto-char (point-min))
     (re-search-forward "^\\*\\* Section Beta")
     (outline-hide-subtree)
     (let ((output-file (my/org-pandoc-eisvogel-export nil nil nil t nil nil)))
       (should (file-exists-p output-file))
       (let ((text (my/org-pandoc-test-pdf-text output-file)))
         (should text)
         (should-not (string-match-p "beta-hidden-text" text))
         (should (string-match-p "alpha-visible-text" text)))))))

(ert-deftest my/org-pandoc-eisvogel-body-only-drops-title ()
  "BODY-ONLY must leave out the title block and use a distinct file name."
  (skip-unless (and (executable-find "pandoc")
                   (executable-find "xelatex")
                   (executable-find "pdftotext")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (let ((output-file (my/org-pandoc-eisvogel-export nil nil nil nil t nil)))
       (should (file-exists-p output-file))
       (should (string-suffix-p "-body.pdf" output-file))
       (let ((text (my/org-pandoc-test-pdf-text output-file)))
         (should text)
         (should-not (string-match-p "Fixture Doc" text))
         (should (string-match-p "alpha-visible-text" text)))))))

(ert-deftest my/org-pandoc-eisvogel-async-scoped-export-opens-after-success ()
  "Combined dispatcher options survive source edits and open the finished PDF."
  (skip-unless (and (executable-find "pandoc") (executable-find "xelatex")
                   (executable-find "pdftotext")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (re-search-forward "^\\*\\* Section Beta$")
     (outline-hide-subtree)
     (goto-char (point-min))
     (re-search-forward "^\\* Section Alpha$")
     (let* ((directory (make-temp-file "export-temp-" t))
            (temporary-file-directory (file-name-as-directory directory))
            process opened)
       (unwind-protect
           (cl-letf (((symbol-function 'browse-url-of-file)
                      (lambda (file &rest _)
                        (should (file-exists-p file))
                        (setq opened file))))
             (let ((output (my/org-pandoc-eisvogel-export-and-open-dispatch t t t t)))
               (setq process (get-process (my/org-pandoc-eisvogel-process-name output)))
               (should (processp process))
               (should (process-live-p process))
               (should-not opened)
               (goto-char (point-max))
               (insert "Later unsaved edit\n")
               (while (process-live-p process) (accept-process-output process 0.1))
               (should (zerop (process-exit-status process)))
               (should (equal opened output))
               (should (string-suffix-p "-Section-Alpha-body.pdf" output))
               (let ((text (my/org-pandoc-test-pdf-text output)))
                 (should (string-match-p "alpha-visible-text" text))
                 (dolist (excluded '("beta-hidden-text" "gamma-other-text"
                                     "Fixture Doc" "Later unsaved edit"))
                   (should-not (string-match-p excluded text))))
               (should-not (directory-files directory nil "\\`[^.]"))))
         (when (and process (process-live-p process)) (delete-process process))
         (when (and process (buffer-live-p (process-buffer process)))
           (kill-buffer (process-buffer process)))
         (delete-directory directory t))))))

(ert-deftest my/org-pandoc-eisvogel-exports-unsaved-region ()
  "Export the selected buffer text, including edits not yet saved to disk."
  (skip-unless (and (executable-find "pandoc") (executable-find "xelatex")
                   (executable-find "pdftotext")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (goto-char (point-max))
     (let ((begin (point))
           (transient-mark-mode t))
       (insert "Selected unsaved text\n")
       (set-mark begin)
       (setq mark-active t)
       (let* ((output (my/org-pandoc-eisvogel-export-dispatch nil nil nil t))
              (text (my/org-pandoc-test-pdf-text output)))
         (should (string-match-p "Selected unsaved text" text))
         (should-not (string-match-p "alpha-visible-text" text))
         (should (buffer-modified-p)))))))

(ert-deftest my/org-pandoc-eisvogel-cleans-up-after-launch-failure ()
  "A failed Pandoc launch must not leave temporary input or header files."
  (skip-unless (executable-find "pandoc"))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (let* ((directory (make-temp-file "export-temp-" t))
            (temporary-file-directory (file-name-as-directory directory)))
       (unwind-protect
           (cl-letf (((symbol-function 'make-process)
                      (lambda (&rest _) (error "Simulated launch failure")))
                     ((symbol-function 'my/org-pandoc-eisvogel--font-available-p)
                      (lambda (_) t)))
             (should (equal "Simulated launch failure"
                            (error-message-string
                             (should-error (my/org-pandoc-eisvogel-export nil t)))))
             (should-not (directory-files directory nil "\\`[^.]")))
         (delete-directory directory t))))))

(ert-deftest my/org-pandoc-eisvogel-async-failure-retains-log-and-cleans-files ()
  "A failed child keeps its diagnostics, cleans snapshots and never opens a PDF."
  (skip-unless (and (executable-find "sh") (executable-find "pandoc")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (let* ((directory (make-temp-file "export-temp-" t))
            (temporary-file-directory (file-name-as-directory directory))
            (start-process (symbol-function 'make-process))
            process opened)
       (unwind-protect
           (cl-letf (((symbol-function 'make-process)
                      (lambda (&rest args)
                        (apply start-process
                               (plist-put args :command
                                          (list (executable-find "sh") "-c"
                                                "printf 'forced failure\\n' >&2; exit 23")))))
                     ((symbol-function 'browse-url-of-file)
                      (lambda (&rest _) (setq opened t))))
             (let ((output (my/org-pandoc-eisvogel-export-and-open-dispatch t nil nil nil)))
               (setq process (get-process (my/org-pandoc-eisvogel-process-name output)))
               (while (process-live-p process) (accept-process-output process 0.1))
               (should (= 23 (process-exit-status process)))
               (should-not (file-exists-p output))
               (should-not opened)
               (should (string-match-p "forced failure"
                                       (with-current-buffer (process-buffer process)
                                         (buffer-string))))
               (should-not (directory-files directory nil "\\`[^.]"))))
         (when (and process (process-live-p process)) (delete-process process))
         (when (and process (buffer-live-p (process-buffer process)))
           (kill-buffer (process-buffer process)))
         (delete-directory directory t))))))

(ert-deftest my/org-pandoc-eisvogel-chosen-subtree-preserves-metadata-and-images ()
  "Chosen-path export respects subtree metadata and resolves relative images."
  (skip-unless (and (executable-find "pandoc") (executable-find "xelatex")
                   (executable-find "pdftotext") (executable-find "pdfimages")))
  (my/org-pandoc-test-in-buffer
   (lambda ()
     (let ((coding-system-for-write 'binary))
       (with-temp-file "pixel.png"
         (set-buffer-multibyte nil)
         (insert (base64-decode-string
                  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC"))))
     (erase-buffer)
     (insert "#+TITLE: Outer title\n#+OPTIONS: toc:nil num:nil\n"
             "#+LATEX_CLASS_OPTIONS: [9pt]\n"
             "#+LATEX_HEADER: \\geometry{left=12mm,right=12mm}\n"
             "* Picture\n:PROPERTIES:\n:EXPORT_TITLE: Local title\n"
             ":EXPORT_OPTIONS: toc:t num:t\n:END:\n** Inner heading\n"
             "[[file:pixel.png]]\n"
             "#+begin_src emacs-lisp :exports both\n(error \"must not execute\")\n#+end_src\n")
     (goto-char (point-min))
     (re-search-forward "^\\* Picture$")
     (let ((chosen (expand-file-name "chosen-output")) default)
       (cl-letf (((symbol-function 'read-file-name)
                  (lambda (_prompt _dir initial &rest _)
                    (setq default initial)
                    chosen)))
         (let* ((output (my/org-pandoc-eisvogel-export-to-file-dispatch nil t nil nil))
                (text (my/org-pandoc-test-pdf-text output)))
           (should (equal output (concat chosen ".pdf")))
           (should (string-suffix-p "-Picture.pdf" default))
           (should (string-match-p "Local title" text))
           (should-not (string-match-p "Outer title" text))
           (should (string-match-p "Contents" text))
           ;; Verify document geometry in the PDF, not just a forwarded option.
           (with-temp-buffer
             (should (zerop (call-process "pdftotext" nil t nil "-bbox" output "-")))
             (goto-char (point-min))
             (let (left-edges)
               (while (re-search-forward "xMin=\"\\([0-9.]+\\)\"" nil t)
                 (push (string-to-number (match-string 1)) left-edges))
               (should left-edges)
               ;; 12 mm is about 34 PDF points; default margins are 57.6 points.
               (should (< 30 (apply #'min left-edges) 40))))
           (with-temp-buffer
             (should (zerop (call-process "pdfimages" nil t nil "-list" output)))
             (should (string-match-p "[[:space:]]image[[:space:]]" (buffer-string))))))))))

;;; org-pandoc-eisvogel-test.el ends here
