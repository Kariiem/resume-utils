# Résumé in Typst

Edit **`resume.typ`**, then compile with [Typst](https://typst.app/):

```sh
typst compile resume.typ                 # creates resume.pdf
typst watch resume.typ                   # rebuilds while editing
```

Tested with Typst 0.15.1. No TeX, Emacs, Docker, installed fonts, or Typst
packages are needed. Sections may span pages; individual entries stay together.

## Icons

`resume-icon-in-use.typ` loads five SVG icons from a local Font Awesome Free
7.2.0 desktop distribution. Download and extract it once:

```sh
curl -fL https://use.fontawesome.com/releases/v7.2.0/fontawesome-free-7.2.0-desktop.zip -o /tmp/fontawesome.zip
unzip /tmp/fontawesome.zip -d /tmp
mv /tmp/fontawesome-free-7.2.0-desktop ./fontawesome
```

Skip this setup if `fontawesome/` already exists. Keep its `LICENSE.txt`.
The directory is ignored by Git; the résumé contains no inline SVGs.

## Checks

With Python 3, Typst, and Poppler (`pdftotext`, `pdfinfo`) installed:

```sh
python3 -m unittest discover -s tests -p 'test_typst.py' -v
```

Checks cover content, links, page format, clipping, entry integrity, and source
order—not pixel matching. The content follows `resume.org` / `resume.tex`;
Typst is edited directly, so changes are not automatically synchronized.

## TeX version

The **`tex-implementation`** branch preserves the Org → LaTeX workflow and its
setup documentation. Older TeX tooling remains in this branch's history/files.

## License

Original contributions use the [Unlicense](LICENSE). Font Awesome icons are
CC BY 4.0; upstream template material retains its own license.
