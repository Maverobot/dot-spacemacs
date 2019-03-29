  ;; Open launch/yaml file in new buffer
  (defun jump-in-launch-file ()
    (interactive)
    (setq current-line (thing-at-point 'line t))
    (setq found-match (string-match "\\$(find [^ ]*)[^ ]*\\.\\(launch\\|yaml\\|xacro\\)" current-line))
    (if found-match
        (progn
          (setq raw-ros-path (match-string 0 current-line))
          (setq ros-path (replace-in-string "find" "rospack find" raw-ros-path))
          (setq absolute-path (shell-command-to-string (concat "/bin/echo -n " ros-path)))
          (setq no-package (string-match "\\[rospack\\] Error: package .* not found" absolute-path))
          (if no-package
              (message (match-string 0 absolute-path))
            (find-file absolute-path)
            )
          )
    )
  )

  (defun replace-in-string (pattern replacement original-text)
    (replace-regexp-in-string (regexp-quote pattern) replacement original-text nil 'literal))

  (when (fboundp 'nxml-mode)
    (defun my-launch-file-config ()
      "For use in `nxml-mode-hook'."
      (spacemacs/set-leader-keys-for-major-mode 'nxml-mode "gg" 'jump-in-launch-file)
      )
    (add-hook 'nxml-mode-hook 'my-launch-file-config)
  )
