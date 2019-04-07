;; Open launch/yaml file in new buffer

(require 'helm)

(setq re-ros-path "\\$(find [^ ]*)[^ ]*\\.\\(launch\\|yaml\\|xacro\\)")
(setq re-pkg "pkg=\"\\([^\"]*\\)\"")

(defun jump-to-file ()
  (interactive)
  (let* ((current-line (thing-at-point 'line t))
         (found-match (string-match re-ros-path current-line)))
    (when found-match
      (let* ((raw-ros-path (match-string 0 current-line))
             (ros-path (replace-in-string "find" "rospack find" raw-ros-path))
             (absolute-path (shell-command-to-string (concat "/bin/echo -n " ros-path)))
             (no-package (string-match "\\[rospack\\] Error: package .* not found" absolute-path)))
        (if no-package
            (message (match-string 0 absolute-path))
          (find-file absolute-path))))))

(defun jump-to-pkg (search)
  (let* ((current-line (thing-at-point 'line t))
         (found-match (string-match re-pkg current-line)))
    (when found-match
      (let* (
             (pkg-name (match-string 1 current-line))
             (absolute-path
              (replace-regexp-in-string "\n$" "" (shell-command-to-string (format "rospack find %s" pkg-name)))))
        (if search
            (helm-browse-project-find-files (concat absolute-path "/"))
          (helm-find-files-1 (concat absolute-path "/")))))))

(defun jump-to-pkg-browse-dir ()
  (interactive)
  (jump-to-pkg nil))

(defun jump-to-pkg-find-files ()
  (interactive)
  (jump-to-pkg t))

(defun replace-in-string (pattern replacement original-text)
  (replace-regexp-in-string (regexp-quote pattern) replacement original-text nil 'literal))

(when (fboundp 'nxml-mode)
  (defun my-launch-file-config ()
    "For use in `nxml-mode-hook'."
    (spacemacs/declare-prefix-for-mode 'nxml-mode "mg" "goto")
    (spacemacs/declare-prefix-for-mode 'nxml-mode "mgp" "ros-package")
    (spacemacs/set-leader-keys-for-major-mode 'nxml-mode "gg" 'jump-to-file)
    (spacemacs/set-leader-keys-for-major-mode 'nxml-mode "gpp" 'jump-to-pkg-browse-dir)
    (spacemacs/set-leader-keys-for-major-mode 'nxml-mode "gpf" 'jump-to-pkg-find-files))
  (add-hook 'nxml-mode-hook 'my-launch-file-config))
