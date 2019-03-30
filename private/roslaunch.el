;; Open launch/yaml file in new buffer

(require 'helm)

(setq re-ros-path "\\$(find [^ ]*)[^ ]*\\.\\(launch\\|yaml\\|xacro\\)")
(setq re-pkg "pkg=\"\\([^\"]*\\)\"")

(defun jump-to-file ()
  (interactive)
  (setq current-line (thing-at-point 'line t))
  (setq found-match (string-match re-ros-path current-line))
  (if found-match
      (progn
        (setq raw-ros-path (match-string 0 current-line))
        (setq ros-path (replace-in-string "find" "rospack find" raw-ros-path))
        (setq absolute-path (shell-command-to-string (concat "/bin/echo -n " ros-path)))
        (setq no-package (string-match "\\[rospack\\] Error: package .* not found" absolute-path))
        (if no-package
            (message (match-string 0 absolute-path))
          (find-file absolute-path)))))

(defun jump-to-pkg-dir ()
  (interactive)
  (setq current-line (thing-at-point 'line t))
  (setq found-match (string-match re-pkg current-line))
  (if found-match
      (progn
        (setq pkg-name (match-string 1 current-line))
        (setq absolute-path
              (replace-regexp-in-string "\n$" "" (shell-command-to-string (format "rospack find %s" pkg-name))))
        (helm-find-files-1 (concat absolute-path "/")))))

(defun replace-in-string (pattern replacement original-text)
  (replace-regexp-in-string (regexp-quote pattern) replacement original-text nil 'literal))

(when (fboundp 'nxml-mode)
  (defun my-launch-file-config ()
    "For use in `nxml-mode-hook'."
    (spacemacs/declare-prefix-for-mode 'nxml-mode "mg" "goto")
    (spacemacs/set-leader-keys-for-major-mode 'nxml-mode "gg" 'jump-to-file)
    (spacemacs/set-leader-keys-for-major-mode 'nxml-mode "gp" 'jump-to-pkg-dir)
  )
  (add-hook 'nxml-mode-hook 'my-launch-file-config)
)
