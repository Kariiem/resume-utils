;;; export-tests.el --- Regression tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(load (expand-file-name "../resume-tex-config.el"
                        (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defun resume-test-export (source)
  (with-temp-buffer
    (org-mode)
    (insert source)
    (org-export-as 'resume nil nil t)))

(ert-deftest resume-inline-escaping ()
  (should (string-match-p
           (regexp-quote "Research \\& Development")
           (resume-test-export "* Research & Development\n:PROPERTIES:\n:TYPE: section\n:END:\n"))))

(ert-deftest resume-list-macros ()
  (let ((output (resume-test-export
                 "* Work\n:PROPERTIES:\n:TYPE: section\n:END:\n** Example\n:PROPERTIES:\n:TYPE: project\n:DATE: 2025\n:END:\n- A bullet.\n")))
    (should (string-match-p (regexp-quote "\\resumeProjectHeading{") output))
    (should (string-match-p (regexp-quote "\\resumeItem{A bullet.}") output))))

(ert-deftest resume-comment-projects-excluded ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "resume.org" resume-tex-directory))
    (org-mode)
    (let ((output (org-export-as 'resume)))
      (should-not (string-match-p "Botiverse\\|Tumbler" output))
      (should (string-match-p "QEMU.org" output))
      (should-not (string-match-p "@@RESUME-" output))
      (should (string-match-p (regexp-quote "/fontawesome/otfs/") output)))))

(ert-deftest resume-config-does-not-change-unrelated-org ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/unrelated-resume-test.org")
    (org-mode)
    (should-not (local-variable-p 'org-latex-pdf-process))))

(ert-deftest resume-mode-is-opt-in-and-buffer-local ()
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "example.org" resume-tex-directory))
    (org-mode)
    (should-not resume-export-mode)
    (resume-export-mode 1)
    (should (local-variable-p 'resume-export-mode))
    (should (eq (key-binding (kbd "C-c r")) #'resume-export-pdf))
    (with-temp-buffer
      (org-mode)
      (should-not resume-export-mode))
    (resume-export-mode -1)
    (should-not resume-export-mode)))

(ert-deftest resume-mode-rejects-unrelated-org ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/unrelated-resume-test.org")
    (org-mode)
    (should-error (resume-export-mode 1) :type 'user-error)
    (should-not resume-export-mode)))

(ert-deftest resume-mode-rejects-non-org-project-buffer ()
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "example.txt" resume-tex-directory))
    (should-error (resume-export-mode 1) :type 'user-error)
    (should-not resume-export-mode)))

(ert-deftest resume-exports-next-to-current-org ()
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "reference/example.org" resume-tex-directory))
    (org-mode)
    (cl-letf (((symbol-function 'org-export-to-file)
               (lambda (backend output &rest _)
                 (should (eq backend 'resume))
                 output)))
      (should (equal (resume-export-tex)
                     (expand-file-name "reference/example.tex" resume-tex-directory))))))

(ert-deftest resume-header-omits-absent-contact-links ()
  (with-temp-buffer
    (org-mode)
    (insert "#+RESUME_NAME: Example Person\n#+RESUME_EMAIL: person@example.com\n")
    (let ((output (org-export-as 'resume)))
      (should (string-match-p "mailto:person@example.com" output))
      (should-not (string-match-p (regexp-quote "\\href{nil}") output))
      (should-not (string-match-p (regexp-quote "\\href{tel:") output))
      (should-not (string-match-p (regexp-quote "\\faGithub\\underline") output)))))

(ert-deftest resume-project-uses-docker-wrapper ()
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "resume.org" resume-tex-directory))
    (org-mode)
    (should (local-variable-p 'org-latex-pdf-process))
    (should (string-match-p "bin/resume-tex" (car org-latex-pdf-process)))))
