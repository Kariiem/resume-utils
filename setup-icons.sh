#!/usr/bin/env bash
# Install only the five Font Awesome SVGs used by the résumé and their license.
set -euo pipefail
root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  printf '%s\n' 'Usage: ./setup-icons.sh' 'Verify existing icons or download the pinned Font Awesome 7.2.0 icons.'
  exit 0
fi
if (( $# )); then printf 'Usage: ./setup-icons.sh\n' >&2; exit 2; fi
cd -- "$root"
verify() { (cd -- "$1" && sha256sum --check "$root/icons.sha256"); }

# Preserve existing distributions, including any extra assets the user keeps.
if [[ -e fontawesome || -L fontawesome ]]; then
  verify "$root"
  exit 0
fi

staging=$(mktemp -d "$root/.resume-icons.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --location --show-error --silent --retry 3 \
  --connect-timeout 20 --max-time 180 \
  https://use.fontawesome.com/releases/v7.2.0/fontawesome-free-7.2.0-desktop.zip \
  -o "$staging/icons.zip"
printf '%s  %s\n' \
  5717251cdd7b3f3df989f9fada0ca65b6609045c04a0c1bd78fb27acb3bf84cb \
  "$staging/icons.zip" | sha256sum --check -
mkdir -p "$staging/fontawesome"
while read -r _checksum path; do
  relative=${path#fontawesome/}
  mkdir -p -- "$staging/fontawesome/$(dirname -- "$relative")"
  unzip -p "$staging/icons.zip" "fontawesome-free-7.2.0-desktop/$relative" \
    > "$staging/fontawesome/$relative"
done < icons.sha256
verify "$staging"
# GNU mv -T refuses to nest the installation inside a concurrently created dir.
[[ ! -e fontawesome && ! -L fontawesome ]] || { printf 'fontawesome appeared during setup; not replacing it\n' >&2; exit 1; }
mv -T -- "$staging/fontawesome" "$root/fontawesome"
