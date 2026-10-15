#!/usr/bin/env bash
# Prepare the pinned sandbox and export with native Emacs; TeX runs in Docker.
set -euo pipefail

root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
font_version=7.2.0
font_archive_sha256=5717251cdd7b3f3df989f9fada0ca65b6609045c04a0c1bd78fb27acb3bf84cb
font_url="https://use.fontawesome.com/releases/v${font_version}/fontawesome-free-${font_version}-desktop.zip"
fonts=${RESUME_FONTAWESOME_DIR:-$root/fontawesome}
image=${RESUME_TEX_IMAGE:-resume-tex:local}
setup_only=false
source_file=

usage() {
  printf '%s\n' \
    'Usage: ./build.sh [--setup-only | FILE.org]' \
    '' \
    'Verify/download Font Awesome, build the linux/amd64 Docker image, and' \
    'export FILE.org (default: resume.org) to sibling TeX/PDF files.' \
    'Relative input paths are resolved from the calling directory.' \
    '' \
    '  --setup-only  Prepare fonts and image without exporting a CV.' \
    '  -h, --help    Show this help.' \
    '' \
    'Environment: RESUME_TEX_IMAGE, RESUME_FONTAWESOME_DIR (absolute path).'
}

fail() { printf 'build.sh: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

if (( $# > 1 )); then usage >&2; exit 2; fi
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --setup-only) setup_only=true ;;
  -*) usage >&2; exit 2 ;;
  *) source_file=${1:-$root/resume.org} ;;
esac

case "$fonts" in
  /*) ;;
  *) fail 'RESUME_FONTAWESOME_DIR must be an absolute path' ;;
esac
# Normalize a trailing slash so staging and installation use the same parent.
while [[ $fonts != / && $fonts == */ ]]; do fonts=${fonts%/}; done

need sha256sum
need docker
if ! "$setup_only"; then
  need emacs
  need realpath
  source_file=$(realpath -e -- "$source_file")
  case "$source_file" in
    "$root"/*.org) ;;
    *) fail 'Pass an existing .org file inside the resume project' ;;
  esac
fi
# Fail before downloading if Docker is unavailable to this user.
docker info >/dev/null

verify_fonts() {
  # The tracked manifest uses fontawesome/ paths; strip that prefix so the
  # same checks also work for an external RESUME_FONTAWESOME_DIR.
  (
    cd -- "$1"
    while read -r checksum filename; do
      printf '%s  %s\n' "$checksum" "${filename#fontawesome/}"
    done < "$root/fontawesome.sha256" | sha256sum --check -
  )
}

staging=
cleanup() { if [[ -n $staging ]]; then rm -rf -- "$staging"; fi; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -e $fonts || -L $fonts ]]; then
  printf 'Verifying existing fonts: %s\n' "$fonts"
  verify_fonts "$fonts" || fail "Fonts do not match fontawesome.sha256; repair or move aside $fonts and retry (nothing was overwritten)"
  [[ -f $fonts/LICENSE.txt ]] || fail "Missing $fonts/LICENSE.txt; retain the font distribution license"
else
  need curl
  need unzip
  parent=$(dirname -- "$fonts")
  mkdir -p -- "$parent"
  staging=$(mktemp -d "$parent/.resume-fontawesome.XXXXXX")
  printf 'Downloading Font Awesome Free %s desktop ZIP\n' "$font_version"
  curl --fail --location --show-error --silent --retry 3 \
    --connect-timeout 20 --max-time 180 "$font_url" -o "$staging/fonts.zip"
  printf '%s  %s\n' "$font_archive_sha256" "$staging/fonts.zip" | sha256sum --check -
  unzip -q "$staging/fonts.zip" -d "$staging/unpacked"
  extracted="$staging/unpacked/fontawesome-free-${font_version}-desktop"
  verify_fonts "$extracted"
  [[ -f $extracted/LICENSE.txt ]] || fail 'Font archive does not contain LICENSE.txt'
  # Never replace a directory that appeared while the download was in progress.
  [[ ! -e $fonts && ! -L $fonts ]] || fail "Font destination appeared during setup: $fonts"
  mv -T -- "$extracted" "$fonts"
fi

export RESUME_FONTAWESOME_DIR="$fonts" RESUME_TEX_IMAGE="$image"
printf 'Building Docker image: %s (linux/amd64)\n' "$image"
docker build --platform linux/amd64 -t "$image" "$root"
if ! "$setup_only"; then
  printf 'Exporting: %s\n' "$source_file"
  # Load the backend explicitly; no personal init file or file-local evals needed.
  emacs -Q --batch --eval '(setq enable-local-variables nil enable-local-eval nil)' \
    -l "$root/resume-tex-config.el" "$source_file" -f resume-export-pdf
fi
