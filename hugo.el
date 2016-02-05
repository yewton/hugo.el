;;; hugo.el --- Helper functions for Hugo -*- lexical-binding: t -*-

;; Copyright (C) 2016 yewton

;; Author: yewton <yewton@gmail.com>
;; Version: 0.0.2
;; URL: https://github.com/yewton/hugo.el
;; Keywords: hugo

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Please see README.md for documentation, or read it online at
;; https://github.com/yewton/hugo.el/

;;; License:

;; This file is not part of GNU Emacs.
;; However, it is distributed under the same license.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'f)
(require 'dash)
(require 'ht)

(defcustom hugo-executable
  "hugo"
  "Name of the hugo executable to use."
  :type 'string
  :group 'hugo)

(defcustom hugo-sites-dir
  nil
  "Hugo sites base direcotry."
  :type 'string
  :group 'hugo)

(defcustom hugo-workdir
  (f-full (f-join user-emacs-directory ".hugo"))
  "A working directory for hugo.el."
  :type 'string
  :group 'hugo)

(defcustom hugo-themes-url
  "https://github.com/spf13/hugoThemes.git"
  "URL for Hugo themes."
  :type 'string
  :group 'hugo)

(defcustom hugo-deploy-script
  "deploy.sh"
  "A script file name to deploy the site."
  :type 'string
  :group 'hugo)

(defcustom hugo-images-dir
  "img"
  "Directory to where put images."
  :type 'string
  :group 'hugo)

(defvar hugo--themes-table nil)
(defvar hugo-buffer "*Hugo*")
(defvar hugo-server-process nil)
(defvar hugo-server-buffer "*Hugo Server*")

(defmacro hugo-call-process (program &rest args)
  `(eq 0 (call-process (executable-find ,program) nil `(,(hugo-buffer) t) nil ,@args)))

(defmacro with-hugo-default-directory (directory &rest body)
  (declare (indent 1) (debug t))
  `(let ((default-directory (or (and ,directory
                                     (file-name-as-directory ,directory))
                                default-directory)))
     ,@body))

(defmacro with-hugo-buffer (&rest body)
  "Eval BODY inside `hugo-buffer'."
  (declare (indent 0) (debug t))
  `(with-current-buffer (hugo-buffer)
     ,@body))

(defun hugo-buffer () (get-buffer-create hugo-buffer))
(defun hugo-server-buffer () (get-buffer-create hugo-server-buffer))

;;;###autoload
(defun hugo-new-site (basedir name)
  "Generate a new site."
  (interactive (list (hugo-sites-dir)
                     (read-string "Site name: ")))
  (let ((path (f-expand name basedir)))
    (if (not (f-dir? path))
        (if (and (hugo-call-process hugo-executable "new" "site" path)
                 (with-hugo-default-directory (f-full path)
                   (hugo-call-process "git" "init")))
            (find-file path)
          (error "Failed to generate a new site. Check %s." hugo-buffer))
      (error "%s already exists." path))))

;;;###autoload
(defun hugo-new-content ()
  "Add a new content."
  (interactive)
  (-if-let (root (hugo-root-dir))
      (let* ((default (format-time-string "post/%Y-%m-%d_%H%M%S.md"))
             (path (read-string (format "Content name(default: %s): " default) nil nil default)))
        (if (with-hugo-default-directory root
              (hugo-call-process hugo-executable "new" path))
            (find-file (f-join root "content" path))
          (error "Failed to create a new content. Check %s" hugo-buffer)))
    (error "Not in a Hugo site.")))

(defun hugo-sites-dir ()
  (or hugo-sites-dir (read-directory-name "Hugo sites directory: ")))

;;;###autoload
(defun hugo-find-site (basedir)
  "Find a directory in `hugo-sites-dir'."
  (interactive (list (hugo-sites-dir)))
  (find-file (f-expand (completing-read
                        "Site: " (-map (lambda (path) (f-base path)) (f-directories basedir)) nil t)
                       basedir)))
;;;###autoload
(defun hugo-find-root-dir ()
  "Find the root directory of current Hugo site."
  (interactive)
  (find-file (hugo-root-dir)))

;;;###autoload
(defun hugo-start-server ()
  "Start hugo-server with draft and future options."
  (interactive)
  (when (process-live-p hugo-server-process)
    (error "Already started."))
  (-if-let (root (hugo-root-dir))
      (with-hugo-default-directory root
        (with-current-buffer (hugo-server-buffer) (erase-buffer))
        (setq hugo-server-process
              (start-process "hugo-server" (hugo-server-buffer) (executable-find hugo-executable) "server" "-DF"))
        (message "Server started(%s)." hugo-server-process))
    (error "Not in a Hugo site.")))

;;;###autoload
(defun hugo-deploy ()
  "Execute `hugo-deploy-script'."
  (interactive)
  (-if-let (root (hugo-root-dir))
      (if (with-hugo-default-directory root
            (hugo-call-process "sh" hugo-deploy-script))
          (message "Deployment complete.")
        (error "Failed to deploy. Check %s" hugo-buffer))
    (error "Not in a Hugo site.")))

;;;###autoload
(defun hugo-stop-server ()
  "Stop the server process if exists."
  (interactive)
  (when (process-live-p hugo-server-process)
    (signal-process hugo-server-process 'int))
  (setq hugo-server-process nil))

;;;###autoload
(defun hugo-open-browser ()
  "Open URL of current running hugo-server in a default browser."
  (interactive)
  (if (process-live-p hugo-server-process)
      (with-current-buffer (process-buffer hugo-server-process)
        (goto-char (point-min))
        (re-search-forward "http://[^ ]+" nil)
        (browse-url-default-browser (match-string 0)))
    (error "Server is not running.")))

(defun hugo--prepare-themes-list ()
  (let ((path (hugo-themes-list-dir)))
    (or (f-dir? path)
        (hugo-call-process "git" "--no-pager" "clone" "-v" hugo-themes-url path))))

;;;###autoload
(defun hugo-install-theme (theme)
  "Add a theme as submodule to current site."
  (interactive (list (progn
                       (unless hugo--themes-table (hugo--prepare-themes-list))
                       (completing-read "Theme: " (ht-keys hugo--themes-table) nil t))))
  (unless (hugo-root-dir)
    (error "Not in a Hugo site."))
  (if (hugo--install-theme theme)
      (message "%s is installed." theme)
    (error "Failed to install %s. Check %s." theme hugo-buffer)))

(defun hugo--install-theme (theme)
  (let ((url (ht-get hugo--themes-table theme)))
    (with-hugo-default-directory (hugo-root-dir)
      (hugo-call-process "git" "--no-pager" "submodule" "add" url (f-join "themes" theme)))))

(defun hugo--build-themes-table ()
  "Returns a name-to-url hash table."
  (let ((default-directory (hugo-themes-list-dir)))
    (with-temp-buffer
      (call-process (executable-find "git") nil t t "--no-pager" "config" "-f" ".gitmodules" "-l")
      (goto-char (point-min))
      (let ((themes (ht-create)))
        (while (re-search-forward "submodule\\.\\([^.]+\\)\\.url=\\(.*\\)" nil t)
          (ht-set! themes (match-string 1) (match-string 2)))
        themes))))

;;;###autoload
(defun hugo-update-themes-list ()
  "Update submodules of themes."
  (interactive)
  (if (hugo--prepare-themes-list)
      (if (hugo--update-themes-list)
          (progn
            (setq hugo--themes-table (hugo--build-themes-table))
            (message "Updated."))
        (error "Failed to update. Check %s." hugo-buffer))
    (error "Failed to prepare. Check %s." hugo-buffer)))

;;;###autoload
(defun hugo-put-image (url path)
  "Fetch a remote image file and insert it at point."
  (interactive
   (let* ((url (read-string "URL: " (hugo--put-image-default-url)))
          (default-path (hugo--put-image-default-path url)))
     (list url (read-file-name "Save as: " nil default-path nil default-path))))
  (f-mkdir (f-dirname path))
  (url-copy-file url path t)
  (let ((title (f-base url)))
    (insert (format "![%s](%s \"%s\")" title (f-relative path default-directory) title))))

(defun hugo--put-image-default-url ()
  (let ((text (if (fboundp 'x-get-clipboard) (x-get-clipboard)
                (if (< 0 (safe-length kill-ring))
                    (substring-no-properties (first kill-ring)) ""))))
    (if (s-match "^\\(?:http\\|ftp\\|https\\)://" text) text "")))

(defun hugo--put-image-default-path (url)
  (let ((filename (f-filename url)))
    (if (hugo-site-p)
        (let ((dir (f-join (hugo-root-dir) "static" hugo-images-dir (f-base buffer-file-name))))
          (f-join dir filename))
      (f-join default-directory filename))))

(defun hugo--update-themes-list ()
  (with-hugo-default-directory (hugo-themes-list-dir)
    (hugo-call-process "git" "--no-pager" "pull" "-v")))

(defun hugo-root-dir ()
  (-when-let (config-file (hugo-config-file))
    (f-full (f-dirname config-file))))

(defun hugo-config-file ()
  (hugo--config-file-1 default-directory))

(defun hugo-site-p (&optional directory)
  (let ((default-directory (or directory default-directory)))
    (not (null (hugo-root-dir)))))

(defun hugo--config-file-1 (path)
  (or (-reduce-from (lambda (memo item)
                      (or memo (let ((config (f-expand (format "config.%s" item) path)))
                                 (when (f-exists? config) config))))
                    nil
                    '("toml" "yaml" "json"))
      (let ((parent (f-parent path)))
        (when parent
          (hugo--config-file-1 parent)))))

(defun hugo-themes-list-dir ()
  (f-full (f-join hugo-workdir "hugoThemes")))

(provide 'hugo)
;;; hugo.el ends here
