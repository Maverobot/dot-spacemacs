;;; config.el --- org-fancy-reveal layer config -*- lexical-binding: t; -*-

;;; Commentary:
;; Load the local org-fancy-reveal helpers and enable the CSS integration.

;;; Code:

(let ((layer-dir (file-name-directory (or load-file-name buffer-file-name))))
  (add-to-list 'load-path (expand-file-name "local/org-fancy-reveal" layer-dir)))

(require 'org-fancy-reveal)
(org-fancy-reveal-enable)

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c r f") #'org-fancy-reveal-export-to-html)
  (define-key org-mode-map (kbd "C-c r b") #'org-fancy-reveal-export-to-html-and-browse)
  (define-key org-mode-map (kbd "C-c r m") #'org-fancy-reveal-insert-metric-cards)
  (define-key org-mode-map (kbd "C-c r c") #'org-fancy-reveal-insert-cards)
  (define-key org-mode-map (kbd "C-c r 2") #'org-fancy-reveal-insert-columns))

;;; config.el ends here
