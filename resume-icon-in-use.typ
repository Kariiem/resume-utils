// Only the icons used by resume.typ. SVG files are read at compile time.
// Font Awesome Free: https://fontawesome.com/license/free (icons: CC BY 4.0).
// Keep the downloaded distribution's LICENSE.txt alongside these assets.
#let icon-files = (
  phone: "fontawesome/svgs/solid/phone.svg",
  email: "fontawesome/svgs/solid/envelope.svg",
  linkedin: "fontawesome/svgs/brands/linkedin.svg",
  github: "fontawesome/svgs/brands/github.svg",
  external: "fontawesome/svgs/solid/up-right-from-square.svg",
)

#let icon(name, size: 9pt) = box(
  baseline: 15%,
  image(icon-files.at(name), height: size),
)
