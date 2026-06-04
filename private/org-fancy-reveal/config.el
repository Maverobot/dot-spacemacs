;;; config.el --- org-fancy-reveal layer config -*- lexical-binding: t; -*-

;;; Commentary:
;; Register org-fancy-reveal lazily.  Do not require Org/ox here: Spacemacs
;; must finish selecting its packaged Org before any Org feature is loaded.

;;; Code:

(let ((layer-dir (file-name-directory (or load-file-name buffer-file-name))))
  (add-to-list 'load-path (expand-file-name "local/org-fancy-reveal" layer-dir)))

(autoload 'org-fancy-reveal-export-to-html "org-fancy-reveal"
  "Export the current Org file to standalone fancy HTML." t)
(autoload 'org-fancy-reveal-export-to-html-and-browse "org-fancy-reveal"
  "Export the current Org file to standalone fancy HTML and browse it." t)
(autoload 'org-fancy-reveal-insert-metric-cards "org-fancy-reveal"
  "Insert a semantic metric card block." t)
(autoload 'org-fancy-reveal-insert-cards "org-fancy-reveal"
  "Insert a semantic cards block." t)
(autoload 'org-fancy-reveal-insert-columns "org-fancy-reveal"
  "Insert semantic two-column special blocks." t)

(with-eval-after-load 'ox
  (require 'org-fancy-reveal))

(with-eval-after-load 'org-re-reveal
  (require 'org-fancy-reveal)
  (org-fancy-reveal-enable))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c r f") #'org-fancy-reveal-export-to-html)
  (define-key org-mode-map (kbd "C-c r b") #'org-fancy-reveal-export-to-html-and-browse)
  (define-key org-mode-map (kbd "C-c r m") #'org-fancy-reveal-insert-metric-cards)
  (define-key org-mode-map (kbd "C-c r c") #'org-fancy-reveal-insert-cards)
  (define-key org-mode-map (kbd "C-c r 2") #'org-fancy-reveal-insert-columns))

;;; config.el ends here
