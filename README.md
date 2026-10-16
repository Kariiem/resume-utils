# Résumé in Typst

**`resume.typ` is the source of truth** for both content and layout.

```sh
./setup-icons.sh                 # once: download/verify the five SVG icons
typst compile resume.typ         # creates resume.pdf
typst watch resume.typ           # rebuilds while editing
```

Requires [Typst](https://typst.app/) (tested with 0.15.1). It uses bundled fonts,
with no package downloads. Sections may span pages; individual entries stay
together.

## Icons

`resume-icon-in-use.typ` reads five SVGs from `fontawesome/`; no inline SVGs.
Setup requires Bash, curl, unzip, and GNU coreutils. It verifies the Font Awesome
Free 7.2.0 archive and extracted assets by SHA-256, keeps `LICENSE.txt`, and never
repairs or replaces an existing directory silently. No font installation is needed.

## Tests

Requires Python 3 and Poppler (`pdftotext`, `pdfinfo`), plus the setup above:

```sh
python3 -m unittest discover -s tests -v
```

Checks cover rendered content, links, pagination, entry integrity, clipping,
source order, and safe icon reuse—not pixel matching.

## Legacy implementation and license

The **`tex-implementation`** branch contains the separate Org/Emacs/Docker/TeX
workflow. None of those tools are needed on `main`.

Original contributions use the [Unlicense](LICENSE). Font Awesome icons are
[CC BY 4.0](https://fontawesome.com/license/free).
