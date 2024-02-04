;;; publish.el --- Build systemcrafters.net

;; Copyright (C) 2021, 2023 David Wilson <david@systemcrafters.net>

;; Author: David Wilson <david@systemcrafters.net>
;; Maintainer: David Wilson <david@systemcrafters.net>
;; URL: https://codeberg.org/SystemCrafters/systemcrafters.net
;; Modifications: Gary James <gary@gmjelec.co.uk>
;; URL: https://github.com/gazj82/gmjelec.co.uk
;; Version: 0.0.2
;; Package-Requires: ((emacs "28.2"))
;; Keywords: hypermedia, blog, feed, rss

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Docs License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Docs License for more details.
;;
;; You should have received a copy of the GNU General Docs License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Usage:
;; emacs -Q --batch -l ./publish.el --funcall dw/publish

;;; Code:

;; Initialize package sources
(require 'package)

;; Set the package installation directory so that packages aren't stored in the
;; ~/.emacs.d/elpa path.
(setq package-user-dir (expand-file-name "./.packages"))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/"))

;; Initialize the package system
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; Install use-package
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
;; Require built-in dependencies
(require 'subr-x)
(require 'cl-lib)
(require 'ox-publish)

;; Install other dependencies
(use-package esxml
  :pin "melpa-stable"
  :ensure t)

(use-package htmlize
  :ensure t)

(setq user-full-name "Gary James")
(setq user-mail-address "gary@gmjelec.co.uk")

(defvar dw/site-url (if (string-equal (getenv "CI") "true")
                        "" ;; Don't hardcode the domain
                      "http://localhost:8080")
  "The URL for the site being generated.")

(defun dw/site-header ()
  (list `(header (@ (class "site-header"))
                 (div (@ (class "container"))
                      (div (@ (class "site-title"))
                           (img (@ (class "logo")
                                   (src ,(concat dw/site-url "/img/gmj_logo.png"))
                                   (alt "G M James Electrical")))))
                 (div (@ (class "site-masthead"))
                      (div (@ (class "container"))
                           (nav (@ (class "nav"))
                                (a (@ (class "nav-link") (href "/")) "Home") " "
                                (a (@ (class "nav-link") (href "/services/")) "Services") " "
                                (a (@ (class "nav-link") (href "/projects/")) "Projects") " "
                                (a (@ (class "nav-link") (href "/contact/")) "Contact")))))))

(defun dw/site-footer ()
  (list `(footer (@ (class "site-footer"))
                 (div (@ (class "container"))
                      (div (@ (class "row"))
                           (div (@ (class "column"))
                                (p (a (@ (href ,(concat dw/site-url "/credits/"))) "Credits"))
                                (p "© 2024 G M James Electrical"))
                           (div (@ (class "column align-right"))
                                (p (a (@ (href ""))
                                      (img (@ (src ,(concat dw/site-url "/img/emacs.png"))
                                              (style "width: 120px")
                                              (alt "Made with emacs")))))))))))

(defun get-article-output-path (org-file pub-dir)
  (let ((article-dir (concat pub-dir
                             (downcase
                              (file-name-as-directory
                               (file-name-sans-extension
                                (file-name-nondirectory org-file)))))))

    (if (string-match "\\/index.org\\|\\/404.org$" org-file)
        pub-dir
      (progn
        (unless (file-directory-p article-dir)
          (make-directory article-dir t))
        article-dir))))

(defun dw/get-commit-hash ()
  "Get the short hash of the latest commit in the current repository."
  (string-trim-right
   (with-output-to-string
     (with-current-buffer standard-output
       (vc-git-command t nil nil "rev-parse" "--short" "HEAD")))))

(cl-defun dw/generate-page (title
                            content
                            info
                            &key
                            (publish-date)
                            (head-extra)
                            (pre-content)
                            (exclude-header)
                            (exclude-footer))
  (concat
   "<!-- Generated from " (dw/get-commit-hash)  " on " (format-time-string "%Y-%m-%d @ %H:%M") " with " org-export-creator-string " -->\n"
   "<!DOCTYPE html>"
   (sxml-to-xml
    `(html (@ (lang "en"))
           (head
            (meta (@ (charset "utf-8")))
            (meta (@ (author "G M James Electrical - Gary James")))
            (meta (@ (name "viewport")
                     (content "width=device-width, initial-scale=1, shrink-to-fit=no")))
            (link (@ (rel "icon") (type "image/png") (href "/img/favicon.png")))
            (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/fonts/iosevka-aile/iosevka-aile.css"))))
            (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/fonts/jetbrains-mono/jetbrains-mono.css"))))
            (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/css/code.css"))))
            (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/css/site.css"))))
            ,(when head-extra head-extra)
            (title ,(concat title " - GMJ Electrical")))
           (body ,@(unless exclude-header
                     (dw/site-header))
                 (div (@ (class "container"))
                      (div (@ (class "site-post"))
                           (h1 (@ (class "site-post-title"))
                               ,title)
                           ,(when publish-date
                              `(p (@ (class "site-post-meta")) ,publish-date))
                           ,(when pre-content pre-content)
                           (div (@ (id "content"))
                                ,content)))
                 ,@(unless exclude-footer
                     (dw/site-footer)))))))

(defun dw/org-html-template (contents info)
  (dw/generate-page (org-export-data (plist-get info :title) info)
                    contents
                    info
                    :publish-date (org-export-data (org-export-get-date info "%B %e, %Y") info)))

(defun dw/org-html-link (link contents info)
  "Removes file extension and changes the path into lowercase file:// links."
  (when (and (string= 'file (org-element-property :type link))
             (string= "org" (file-name-extension (org-element-property :path link))))
    (org-element-put-property link :path
                              (downcase
                               (file-name-sans-extension
                                (org-element-property :path link)))))

  (let ((exported-link (org-export-custom-protocol-maybe link contents 'html info)))
    (cond
     (exported-link exported-link)
     ((and (equal contents nil) (not (org-export-inline-image-p link)))     
      (format "<a href=\"%s\">%s</a>"
              (org-element-property :raw-link link)
              (org-element-property :raw-link link)))
     ((string-prefix-p "/" (org-element-property :raw-link link))
      (format "<a href=\"%s\">%s</a>"
              (org-element-property :raw-link link)
              contents))
     (t (org-export-with-backend 'html link contents info)))))

(defun dw/make-heading-anchor-name (headline-text)
  (thread-last headline-text
               (downcase)
               (replace-regexp-in-string " " "-")
               (replace-regexp-in-string "[^[:alnum:]_-]" "")))

(defun dw/org-html-headline (headline contents info)
  (let* ((text (org-export-data (org-element-property :title headline) info))
         (level (org-export-get-relative-level headline info))
         (level (min 7 (when level (1+ level))))
         (anchor-name (dw/make-heading-anchor-name text))
         (attributes (org-element-property :ATTR_HTML headline))
         (container (org-element-property :HTML_CONTAINER headline))
         (container-class (and container (org-element-property :HTML_CONTAINER_CLASS headline))))
    (when attributes
      (setq attributes
            (format " %s" (org-html--make-attribute-string
                           (org-export-read-attribute 'attr_html `(nil
                                                                   (attr_html ,(split-string attributes))))))))
    (concat
     (when (and container (not (string= "" container)))
       (format "<%s%s>" container (if container-class (format " class=\"%s\"" container-class) "")))
     (if (not (org-export-low-level-p headline info))
         (format "<h%d%s><a id=\"%s\" class=\"anchor\" href=\"#%s\">¶</a>%s</h%d>%s"
                 level
                 (or attributes "")
                 anchor-name
                 anchor-name
                 text
                 level
                 (or contents ""))
       (concat
        (when (org-export-first-sibling-p headline info) "<ul>")
        (format "<li>%s%s</li>" text (or contents ""))
        (when (org-export-last-sibling-p headline info) "</ul>")))
     (when (and container (not (string= "" container)))
       (format "</%s>" (cl-subseq container 0 (cl-search " " container)))))))

(org-export-define-derived-backend 'site-html 'html
                                   :translate-alist
                                   '((template . dw/org-html-template)
                                     (link . dw/org-html-link)
                                     (headline . dw/org-html-headline)))

(defun org-html-publish-to-html (plist filename pub-dir)
  "Publish an org file to HTML, using the FILENAME as the output directory."
  (let ((article-path (get-article-output-path filename pub-dir)))
    (cl-letf (((symbol-function 'org-export-output-file-name)
               (lambda (extension &optional subtreep pub-dir)
                 ;; The 404 page is a special case, it must be named "404.html"
                 (concat article-path
                         (if (string= (file-name-nondirectory filename) "404.org") "404" "index")
                         extension))))
      (org-publish-org-to 'site-html
                          filename
                          (concat "." (or (plist-get plist :html-extension)
                                          "html"))
                          plist
                          article-path))))

(setq org-publish-use-timestamps-flag t
      org-publish-timestamp-directory "./.org-cache/"
      org-export-with-section-numbers nil
      org-export-use-babel nil
      org-export-with-smart-quotes t
      org-export-with-sub-superscripts nil
      org-export-with-tags 'not-in-toc
      org-html-htmlize-output-type 'css
      org-html-prefer-user-labels t
      org-html-link-home dw/site-url
      org-html-link-use-abs-url t
      org-html-link-org-files-as-html t
      org-html-html5-fancy t
      org-html-self-link-headlines t
      org-export-with-toc nil
      make-backup-files nil)

(defun dw/format-project-entry (entry style project)
  "Format posts with author and published data in the index page."
  (cond ((not (directory-name-p entry))
         (format "[[file:%s][%s]] - %s · %s"
                 entry
                 (org-publish-find-title entry project)
                 (car (org-publish-find-property entry :author project))
                 (format-time-string "%B %d, %Y"
                                     (org-publish-find-date entry project))))
        ((eq style 'tree) (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(defun dw/project-sitemap (title files)
  (format "#+title: %s\n\n%s"
          title
          (mapconcat (lambda (file)
                       (format "- %s\n" file))
                     (cadr files)
                     "\n")))

(setq org-publish-project-alist
      (list '("systemcrafters:main"
              :base-directory "./content"
              :base-extension "org"
              :publishing-directory "./public"
              :publishing-function org-html-publish-to-html
              :with-title nil
              :with-timestamps nil)
            '("systemcrafters:assets"
              :base-directory "./assets"
              :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|woff2\\|ttf"
              :publishing-directory "./public"
              :recursive t
              :publishing-function org-publish-attachment)
            '("systemcrafters:projects"
              :base-directory "./content/projects"
              :base-extension "org"
              :publishing-directory "./public/projects"
              :publishing-function org-html-publish-to-html
              :auto-sitemap t
              :sitemap-filename "../projects.org"
              :sitemap-title "G M James projects"
              :sitemap-format-entry dw/format-project-entry
              :sitemap-style list
              ;; :sitemap-function dw/project-sitemap
              :sitemap-sort-files anti-chronologically
              :with-title nil
              :with-timestamps nil)))

(defun dw/publish ()
  "Publish the entire site."
  (interactive)

  (org-publish-all (string-equal (or (getenv "FORCE")
                                     (getenv "CI"))
                                 "true"))

  ;; Copy the domains file to ensure the custom domain resolves
  (copy-file ".domains" "public/.domains" t))

(provide 'publish)
;;; publish.el ends here
