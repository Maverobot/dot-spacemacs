;;; org-fancy-reveal-test.el --- Tests for org-fancy-reveal -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)

(defvar org-re-reveal-extra-css "")

(defconst org-fancy-reveal-test--layer-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Layer root used by org-fancy-reveal tests.")

(add-to-list 'load-path
             (expand-file-name "local/org-fancy-reveal" org-fancy-reveal-test--layer-root))

(defconst org-fancy-reveal-test--repo-root
  (file-name-as-directory
   (or (getenv "ORG_FANCY_REVEAL_TEST_REPO")
       (expand-file-name "../.." org-fancy-reveal-test--layer-root)))
  "Repository root used by org-fancy-reveal tests.")

(defconst org-fancy-reveal-test--deferred-features
  '(org ox org-re-reveal magit evil evil-collection transient which-key)
  "Features that layer config must not load at startup.")

(defun org-fancy-reveal-test--unload-features (features)
  "Unload loaded FEATURES for lazy-loading assertions."
  (dolist (feature features)
    (when (featurep feature)
      (unload-feature feature t))))

(ert-deftest org-fancy-reveal-config-does-not-load-org-or-keymap-packages ()
  (let ((config-file (expand-file-name "private/org-fancy-reveal/config.el"
                                        org-fancy-reveal-test--repo-root)))
    (org-fancy-reveal-test--unload-features
     (cons 'org-fancy-reveal org-fancy-reveal-test--deferred-features))
    (load-file config-file)
    (dolist (feature org-fancy-reveal-test--deferred-features)
      (should-not (featurep feature)))))

(ert-deftest org-fancy-reveal-require-does-not-load-org-or-ox ()
  (org-fancy-reveal-test--unload-features '(org-fancy-reveal org ox org-re-reveal))
  (require 'org-fancy-reveal)
  (should-not (featurep 'org))
  (should-not (featurep 'ox))
  (should-not (featurep 'org-re-reveal)))

(ert-deftest org-fancy-reveal-does-not-load-magit-or-transient ()
  (let ((config-file (expand-file-name "private/org-fancy-reveal/config.el"
                                        org-fancy-reveal-test--repo-root)))
    (org-fancy-reveal-test--unload-features
     '(org-fancy-reveal magit magit-status evil evil-collection transient))
    (load-file config-file)
    (should-not (featurep 'magit))
    (should-not (featurep 'magit-status))
    (should-not (featurep 'evil))
    (should-not (featurep 'evil-collection))
    (should-not (featurep 'transient))))

(ert-deftest org-fancy-reveal-add-css-path-appends-once ()
  (require 'org-fancy-reveal)
  (let ((first "/tmp/a.css")
        (second "/tmp/b.css"))
    (should (equal (org-fancy-reveal--add-css-path "" first) first))
    (should (equal (org-fancy-reveal--add-css-path first first) first))
    (should (equal (org-fancy-reveal--add-css-path first second)
                   (concat first "\n" second)))))

(ert-deftest org-fancy-reveal-enable-adds-css-to-org-re-reveal ()
  (require 'org-fancy-reveal)
  (let ((original-extra-css org-re-reveal-extra-css))
    (unwind-protect
        (progn
          (setq org-re-reveal-extra-css "")
          (org-fancy-reveal--enable-now)
          (should (string-match-p "org-fancy-reveal.css" org-re-reveal-extra-css))
          (let ((once org-re-reveal-extra-css))
            (org-fancy-reveal--enable-now)
            (should (equal org-re-reveal-extra-css once))))
      (setq org-re-reveal-extra-css original-extra-css))))

(ert-deftest org-fancy-reveal-export-and-browse-accepts-dispatch-arguments ()
  (require 'org-fancy-reveal)
  (let* ((source (make-temp-file "org-fancy-reveal-browse" nil ".org"))
         (output (concat (file-name-sans-extension source) ".html"))
         opened-file)
    (unwind-protect
        (progn
          (with-temp-file source
            (insert "#+TITLE: Fancy Browse Test\n\n* Slide\nBody\n"))
          (with-current-buffer (find-file-noselect source)
            (unwind-protect
                (cl-letf (((symbol-function 'browse-url-of-file)
                           (lambda (file &rest _args)
                             (setq opened-file file))))
                  (should (equal (org-fancy-reveal-export-to-html-and-browse nil nil nil nil)
                                 output))
                  (should (equal opened-file output)))
              (kill-buffer))))
      (delete-file source)
      (when (file-exists-p output)
        (delete-file output)))))

(ert-deftest org-fancy-reveal-insert-metric-cards-snippet-is-semantic-org ()
  (require 'org)
  (require 'org-fancy-reveal)
  (with-temp-buffer
    (org-mode)
    (org-fancy-reveal-insert-metric-cards)
    (let ((text (buffer-string)))
      (should (string-match-p "#\\+begin_metric_cards" text))
      (should (string-match-p "::" text))
      (should-not (string-match-p "<div" text)))))

(ert-deftest org-fancy-reveal-export-to-html-runs-standalone-exporter ()
  (require 'org-fancy-reveal)
  (let* ((source (make-temp-file "org-fancy-reveal" nil ".org"))
         (output (concat (file-name-sans-extension source) ".html")))
    (unwind-protect
        (progn
          (with-temp-file source
            (insert "#+TITLE: Fancy Export Test\n\n")
            (insert "* First slide\n")
            (insert "#+begin_metric_cards\n")
            (insert "- 6R :: *Six revolute joints.* Works.\n")
            (insert "#+end_metric_cards\n"))
          (with-current-buffer (find-file-noselect source)
            (unwind-protect
                (let ((result (org-fancy-reveal-export-to-html nil nil nil nil)))
                  (should (equal result output))
                  (should (file-exists-p output))
                  (with-temp-buffer
                    (insert-file-contents output)
                    (should (search-forward "Fancy Export Test" nil t))
                    (should (search-forward "slide-area" nil t))))
              (kill-buffer)))
      (delete-file source)
      (when (file-exists-p output)
        (delete-file output))))))

;;; org-fancy-reveal-test.el ends here
