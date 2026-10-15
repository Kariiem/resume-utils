;;; export-tests.el --- Regression tests -*- lexical-binding: t; -*-
(require 'ert)
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

(ert-deftest resume-project-uses-docker-wrapper ()
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "resume.org" resume-tex-directory))
    (org-mode)
    (should (local-variable-p 'org-latex-pdf-process))
    (should (string-match-p "bin/resume-tex" (car org-latex-pdf-process)))))
