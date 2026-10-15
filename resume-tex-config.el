;;; resume-tex-config.el --- Org resume export via Docker -*- lexical-binding: t; -*-

(require 'org)
(require 'ox-latex)

(defconst resume-tex-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the template, compiler wrapper and resume.org.")

(defun resume-tex--read-template (&optional info)
  (with-temp-buffer
    (insert-file-contents
     (if-let* ((template (plist-get info :resume-template)))
         (expand-file-name template
                           (file-name-directory (plist-get info :input-file)))
       (expand-file-name "resume-template.tex" resume-tex-directory)))
    (buffer-string)))

(defun resume-tex--text (value info)
  "Export Org inline markup in VALUE, including LaTeX escaping."
  (org-export-data (org-element-parse-secondary-string
                    (or value "") (org-element-restriction 'paragraph)) info))

(defun resume-tex--header (info)
  (let ((text (lambda (key) (resume-tex--text (plist-get info key) info))))
    (concat
     "\\begin{center}\n{\\Huge \\scshape " (funcall text :resume-name) "}"
     (when (plist-get info :resume-location)
       (concat "\\\\ \\vspace{1pt} " (funcall text :resume-location)))
     "\\\\ \\vspace{1pt} \\small\n"
     (mapconcat
      (lambda (contact)
        (pcase-let ((`(,key ,label ,prefix ,icon ,raise) contact))
          (when-let* ((url (plist-get info key)))
            (format "\\href{%s%s}{\\raisebox{%s\\height}\\%s\\underline{%s}~}\n"
                    prefix url raise icon (funcall text label)))))
      '((:resume-phone-uri :resume-phone "tel:" "faPhone" "-0.1")
        (:resume-email :resume-email "mailto:" "faEnvelope" "-0.2")
        (:resume-linkedin :resume-name "" "faLinkedinSquare" "-0.2")
        (:resume-github :resume-github-label "" "faGithub" "-0.2")) "")
     "\\vspace{-8pt}\n\\end{center}\n")))

(defun resume-tex-template (contents info)
  (let ((template (resume-tex--read-template info)))
    (setq template (string-replace "@@RESUME-HEADER@@" (resume-tex--header info) template))
    (string-replace "@@RESUME-BODY@@" contents template)))

(defun resume-tex-headline (headline contents info)
  "Translate headings and their property drawers into the resume macros."
  (let* ((title (org-export-data (org-element-property :title headline) info))
         (type (org-element-property :TYPE headline))
         (prop (lambda (key) (resume-tex--text (org-element-property key headline) info)))
         (space (org-element-property :SPACE_AFTER headline)))
    (concat
     (pcase type
       ("section"
        (concat "\\section{" title "}\n"
                (when-let* ((before (org-element-property :SPACE_BEFORE headline)))
                  (format "\\vspace{%s}\n" before))
                "\\resumeSubHeadingListStart\n" contents
                "\\resumeSubHeadingListEnd\n"))
       ("education"
        (format "\\resumeSubheading{%s}{%s}{%s}{%s}\n%s"
                title (funcall prop :DATE) (funcall prop :QUALIFICATION)
                (funcall prop :LOCATION) (or contents "")))
       ((or "experience" "project")
        (let* ((url (org-element-property :URL headline))
               (label (if (equal type "project") (concat "\\underline{" title "}") title))
               (heading (concat "{\\textbf{\\large{" label "}}}"
                                (when url (format "\\href{%s}{\\raisebox{-0.1\\height}\\faExternalLink}" url)))))
          (concat
           (if (equal type "experience")
               (format "\\resumeExperienceHeading{%s}{%s}{%s}\n" heading
                       (funcall prop :DATE) (funcall prop :ORGANIZATION))
             (format "\\resumeProjectHeading{%s}{%s}\n" heading (funcall prop :DATE)))
           contents)))
       ("skills"
        (concat "\\section{" title "}\n"
                "\\begin{itemize}[leftmargin=0.15in,label={}]\n\\small{\\item{\n"
                contents "}}\n\\end{itemize}\n"))
       ("skill"
        (format "\\textbf{\\normalsize{%s:}}{\\normalsize{ %s}} \\\\\n"
                title (funcall prop :VALUE)))
       (_ (error "Unknown or missing TYPE property on heading: %s" title)))
     (when space (format "\\vspace{%s}\n" space)))))

(defun resume-tex-plain-list (_list contents _info)
  (concat "\\resumeItemListStart\n" contents "\\resumeItemListEnd\n"))

(defun resume-tex-item (_item contents _info)
  (format "\\resumeItem{%s}\n" (string-trim contents)))

(org-export-define-derived-backend 'resume 'latex
  :options-alist
  '((:resume-template "RESUME_TEMPLATE" nil nil t)
    (:resume-name "RESUME_NAME" nil nil t)
    (:resume-location "RESUME_LOCATION" nil nil t)
    (:resume-phone "RESUME_PHONE" nil nil t)
    (:resume-phone-uri "RESUME_PHONE_URI" nil nil t)
    (:resume-email "RESUME_EMAIL" nil nil t)
    (:resume-linkedin "RESUME_LINKEDIN" nil nil t)
    (:resume-github "RESUME_GITHUB" nil nil t)
    (:resume-github-label "RESUME_GITHUB_LABEL" nil nil t))
  :translate-alist '((template . resume-tex-template)
                     (headline . resume-tex-headline)
                     (plain-list . resume-tex-plain-list)
                     (item . resume-tex-item))
  :menu-entry '(?r "Resume" ((?t "Export TeX" resume-export-tex)
                             (?p "Export PDF via Docker" resume-export-pdf))))

(defun resume-tex--setup ()
  "Configure only this project's buffers; leave other Org/TeX work alone."
  (when (and buffer-file-name
             (file-in-directory-p buffer-file-name resume-tex-directory))
    (setq-local org-latex-pdf-process
                (list (concat (shell-quote-argument
                               (expand-file-name "bin/resume-tex" resume-tex-directory))
                              " \"%f\"")))
    (when (derived-mode-p 'latex-mode 'LaTeX-mode)
      (setq-local TeX-command-extra-options "")
      (setq-local TeX-command-default "Resume Docker")
      (setq-local TeX-command-list
                  (cons (list "Resume Docker"
                              (concat (shell-quote-argument
                                       (expand-file-name "bin/resume-tex" resume-tex-directory))
                                      " %t")
                              'TeX-run-TeX nil t :help "Compile in sandbox")
                        (and (boundp 'TeX-command-list) TeX-command-list))))))

(add-hook 'org-mode-hook #'resume-tex--setup)
(add-hook 'LaTeX-mode-hook #'resume-tex--setup)
(add-hook 'latex-mode-hook #'resume-tex--setup)

(define-minor-mode resume-export-mode
  "Buffer-local CV export bindings; enable from an Org file's local variables.
Only Org files inside `resume-tex-directory' may enable this mode.
Use C-c r to export this file to its sibling PDF through Docker."
  :lighter " Resume"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c r") #'resume-export-pdf)
            map)
  (when resume-export-mode
    (unless (and (derived-mode-p 'org-mode) buffer-file-name
                 (file-in-directory-p buffer-file-name resume-tex-directory))
      (setq resume-export-mode nil)
      (user-error "Resume export mode requires an Org file inside %s"
                  resume-tex-directory))
    (resume-tex--setup)))

(defun resume-export-tex (&optional _async _subtreep _visible-only _body-only _ext-plist)
  "Export the current Org file to sibling TeX; default to resume.org in batch."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (find-file (expand-file-name "resume.org" resume-tex-directory)))
  (resume-tex--setup)
  ;; Resume export never needs to evaluate source blocks on the host.
  (let ((org-export-use-babel nil))
    (org-export-to-file 'resume (concat (file-name-sans-extension buffer-file-name)
                                       ".tex"))))

(defun resume-export-pdf (&optional _async _subtreep _visible-only _body-only _ext-plist)
  "Export this Org file to sibling TeX and PDF in the Docker sandbox."
  (interactive)
  (org-latex-compile (resume-export-tex)))

(provide 'resume-tex-config)
;;; resume-tex-config.el ends here
