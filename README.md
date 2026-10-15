# Org résumé with sandboxed XeLaTeX

Edit **`resume.org`** for content and **`resume-template.tex`** for presentation.
Native Emacs exports `resume.tex`; Docker compiles `resume.pdf`. Neither Emacs
nor Font Awesome is installed in the image. No host TeX installation is needed.

## Build and export

Requirements: native Emacs with Org (tested with `emacs -Q`), Docker, and the
Font Awesome 7 Free distribution already in `fontawesome/` (ignored by Git).
Keep its license with the distribution. The template uses these files:

- `fontawesome/otfs/Font Awesome 7 Free-Solid-900.otf`
- `fontawesome/otfs/Font Awesome 7 Brands-Regular-400.otf`

From this directory:

```sh
sha256sum -c fontawesome.sha256  # verify the local font distribution
# For reproducible architecture as well as dependencies, build on linux/amd64.
docker build --platform linux/amd64 -t resume-tex:local .
emacs -Q --batch -l ./resume-tex-config.el -f resume-export-pdf
```

The output is **`resume.pdf`**. To export TeX without Docker:

```sh
emacs -Q --batch -l ./resume-tex-config.el -f resume-export-tex
```

To compile an already exported TeX file: `./bin/resume-tex resume.tex`.
The wrapper also accepts paths inside the project, such as
`./bin/resume-tex other/example.tex`, and compiles in that file's directory.
This runs XeLaTeX twice and stops on errors. Emacs reports compilation output
in `*Org PDF LaTeX Output*`; running the wrapper directly retains the `.log`.
Org normally removes intermediate files following a successful compilation.

## Native Emacs integration

Add this **after your existing Org/TeX configuration**:

```elisp
(load-file (expand-file-name "~/Work/resume/resume-tex-config.el"))
```

Reopen `resume.org` if it was already open, or call `M-x resume-export-pdf`.
The Org export menu also provides **`C-c C-e r p`** (PDF) and **`C-c C-e r t`**
(TeX). Use this custom backend, not the ordinary LaTeX export menu: ordinary
LaTeX export doesn't understand the résumé's heading properties.

For this project's TeX buffers, AUCTeX's default command becomes **Resume
Docker** (`C-c C-c`). Its command-specific options do not inherit the host's
`-shell-escape` setting. Other Org/TeX projects are not reconfigured. Existing
native AUCTeX commands remain available if deliberately selected; the résumé
workflow itself always uses the Docker wrapper. Async/subtree export is not
implemented: these commands intentionally export the whole résumé synchronously.

Before configuring this project, the existing `~/.emacs.d/lisp/init-org.el`,
`init-tex.el`, and package selections were inspected: Org, `org-tidy`, AUCTeX,
and `pdf-tools` are already in use. No changes to your personal Emacs config
were made and no new Emacs packages are required.

## Private family CVs and the export minor mode

`other/` is ignored by Git, including its Org sources, templates, fonts,
original inputs under `other/reference/`, and generated TeX/PDF outputs.
Do not force-add it: ignore rules are not encryption or access control.

Each CV exports beside its Org file: `other/example.org` becomes
`other/example.tex` and `other/example.pdf`, without overwriting `resume.pdf`.
The moved original inputs were also preserved under `other/reference/` before
export, so regenerated files do not destroy the source documents.

`resume-export-mode` is **buffer-local and opt-in**. Its **`C-c r`** binding
exports the current CV to PDF. It can only be enabled in Org file buffers
inside this project; it is not automatically enabled by an Org hook. The
included files enable it through their footer's local variables. When Emacs
asks, review and approve these local evaluations for your trusted CV files:

```org
# Local Variables:
# eval: (load (expand-file-name "../resume-tex-config.el" (file-name-directory (buffer-file-name))))
# eval: (resume-export-mode 1)
# End:
```

Use `./resume-tex-config.el` rather than `../resume-tex-config.el` for Org files
at the project root. Reopen the file or run `M-x normal-mode` to apply a changed
footer. Disabling `M-x resume-export-mode` removes the binding from that buffer.

Optional contact keywords may be omitted; no empty contact links are generated.
`#+RESUME_TEMPLATE: example-template.tex` selects a trusted template relative
to the Org file; the shared template remains the default. Template files use
`@@RESUME-HEADER@@` and `@@RESUME-BODY@@` substitution markers.

## Content model

- `#+RESUME_*` keywords hold contact information.
- Level-one headings have `TYPE: section` or `TYPE: skills`.
- Entries use `TYPE: education`, `experience`, or `project`.
- `DATE`, `QUALIFICATION`, `LOCATION`, `ORGANIZATION`, and `URL` supply macro
  arguments. Org inline markup and text escaping work in text properties.
  URLs are literal LaTeX URL arguments; use trusted, well-formed URLs.
- Ordinary Org bullets become `\resumeItem` calls.
- Skill headings have `TYPE: skill` and a `VALUE` property.
- `SPACE_BEFORE` (sections) and `SPACE_AFTER` preserve the source's layout
  adjustments, as TeX dimensions such as `-13pt`.
- `COMMENT` headings preserve the original disabled projects without exporting
  them. Remove `COMMENT` to enable one.

`resume.tex` and `resume.pdf` are tracked build outputs. Do not edit the generated
TeX directly: the next Org export overwrites it. Arbitrary Babel evaluation is
disabled during résumé export; no source-block execution is needed.

## Reproducibility and sandbox boundary

The Dockerfile pins the Debian base by digest and packages through the
2025-02-10 Debian snapshot. TeX packages cannot silently roll forward. A fixed
`SOURCE_DATE_EPOCH` controls PDF timestamps; the mounted fonts are identified
by `fontawesome.sha256`. Repeat exports on this machine produced identical
SHA-256 hashes. Bit-identical image rebuilds or PDFs across different Emacs/Org
versions and architectures are not claimed.

The image is about **963 MB unpacked** on amd64. It uses `--no-install-recommends`
and avoids `texlive-full`, Emacs, a font bundle, and latexmk. XeTeX and the
LaTeX-extra collection (needed by the template) still make TeX relatively large.
Only the tiny compiler script is copied into the image, not résumé data or fonts.

The compiler runs as your UID/GID, with no network, no capabilities, no shell
escape, no privilege escalation, a read-only container filesystem, bounded
resources, and a temporary `/tmp`. The project is mounted read/write at `/work`
so TeX can create output. Fonts are separately mounted read-only at
`/fontawesome` and `/work/fontawesome` (the second prevents a writable alias
through the project mount).

**This is not isolation from project files:** TeX can read/write the mounted
project, including `.git`. Treat templates and raw LaTeX as trusted. Native
Emacs also reads Org outside Docker; this does not sandbox Emacs itself.

Optional wrapper environment variables:

- `RESUME_TEX_IMAGE`: image name (default `resume-tex:local`).
- `RESUME_FONTAWESOME_DIR`: absolute directory containing `otfs/`.

## Original sources and verification

`reference/original-resume.tex` and `reference/original-resume.pdf` preserve
both initial inputs. **They are not matching revisions:** the PDF includes a
Backend Engineer role and other wording/contact changes absent from the TeX.
The Org conversion deliberately follows the supplied **TeX**, not that PDF.
The generated résumé is one letter-size page; the original PDF is two pages.

The template retains the original macros and geometry. Necessary engine fixes:
pdfTeX-only Unicode primitives were removed for XeTeX, and the unavailable
`fontawesome7` LaTeX package was replaced by direct OTF glyph definitions.
The icon distribution is mounted, not copied or installed in the image.
A reference compilation of the original TeX body with this compatible preamble
also produced one page, with matching content (apart from whitespace in PDF
text extraction). The generated page was visually inspected, including icons.

Run regression tests without Docker:

```sh
emacs -Q --batch -l tests/export-tests.el -f ert-run-tests-batch-and-exit
```

Integration/repeatability check:

```sh
emacs -Q --batch -l ./resume-tex-config.el -f resume-export-pdf
sha256sum resume.pdf
emacs -Q --batch -l ./resume-tex-config.el -f resume-export-pdf
sha256sum resume.pdf  # should match
pdfinfo resume.pdf
```
