# Org résumé with sandboxed XeLaTeX

Edit **`resume.org`** for content and **`resume-template.tex`** for presentation.
Native Emacs exports `resume.tex`; Docker compiles `resume.pdf`. Neither Emacs
nor Font Awesome is installed in the image. No host TeX installation is needed.

## License

Original contributions to this project are dedicated to the public domain under
[the Unlicense](LICENSE). Third-party materials, including Font Awesome and any
upstream template material, remain subject to their respective licenses; this
dedication does not override those terms.

## Build and export

Requirements: Bash, native Emacs with Org (tested with `emacs -Q`), Docker
(accessible to your user), and GNU coreutils (`sha256sum`, `realpath`, `mv -T`).
For the first font download, also install `curl` and `unzip`.

From this directory:

```sh
./build.sh
```

This verifies the fonts, builds `resume-tex:local` for `linux/amd64` using
Docker's build cache, and exports **`resume.pdf`** with native Emacs. It works
from other directories too when invoked by its path. It does not install host
packages or change your personal Emacs configuration. Batch export disables
file-local variables/evaluations and loads the project's backend explicitly.
Only export trusted Org/LaTeX sources; the sandbox limitations below still apply.

If `fontawesome/` is absent, the script downloads the pinned **Font Awesome Free
7.2.0 desktop ZIP** (not a tar archive) from:

https://use.fontawesome.com/releases/v7.2.0/fontawesome-free-7.2.0-desktop.zip

The archive's SHA-256 is pinned in `build.sh`; all three extracted OTF files are
also checked against `fontawesome.sha256` before installation. The distribution,
including `LICENSE.txt`, is retained in `fontawesome/` (ignored by Git). Temporary
downloads are removed on exit. Existing font directories are verified and left
untouched: missing or mismatched fonts, or a missing license, stop the build
rather than silently replacing local files. Move an unwanted/incomplete directory
aside and rerun to download a clean copy.

```sh
./build.sh --setup-only        # fonts + image only; no TeX/PDF export
./build.sh other/example.org   # export another trusted project CV
./build.sh --help
```

`RESUME_TEX_IMAGE` selects the image tag to build and use;
`RESUME_FONTAWESOME_DIR` selects an absolute font directory to verify or populate.
Relative CV paths are resolved from your calling directory. Outputs are siblings
of the selected Org file; the default is always the project's `resume.org`.
An amd64-capable Docker environment is required (native amd64 or configured
emulation on another architecture).

The equivalent manual steps, with fonts already installed, remain:

```sh
sha256sum -c fontawesome.sha256
# For reproducible architecture as well as dependencies, build on linux/amd64.
docker build --platform linux/amd64 -t resume-tex:local .
emacs -Q --batch -l ./resume-tex-config.el -f resume-export-pdf
```

To export TeX without Docker:

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
python3 -m unittest discover -s tests -p 'test_build.py' -v
```

The build-script tests use temporary fixtures and mock downloads, Docker and
Emacs; they exercise ZIP extraction, checksum failures, existing-font reuse and
preservation, environment overrides and command arguments without network access
or generating a real PDF. They require Bash, coreutils, `unzip` and Python 3's
standard library.

Integration/repeatability check:

```sh
emacs -Q --batch -l ./resume-tex-config.el -f resume-export-pdf
sha256sum resume.pdf
emacs -Q --batch -l ./resume-tex-config.el -f resume-export-pdf
sha256sum resume.pdf  # should match
pdfinfo resume.pdf
```
