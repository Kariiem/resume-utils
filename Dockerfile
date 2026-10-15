# Frozen base and Debian repository: no rolling TeX package downloads.
FROM debian:bookworm-20250203-slim@sha256:40b107342c492725bc7aacbe93a49945445191ae364184a6d24fedb28172f6f7
ARG DEBIAN_SNAPSHOT=20250210T000000Z
RUN rm -f /etc/apt/sources.list.d/debian.sources \
 && printf 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/%s/ bookworm main\n' "$DEBIAN_SNAPSHOT" > /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      texlive-xetex texlive-latex-extra texlive-fonts-recommended \
 && rm -rf /var/lib/apt/lists/*
# Emacs and Font Awesome deliberately do not live in the image.
COPY docker/compile /usr/local/bin/resume-compile
ENV HOME=/tmp SOURCE_DATE_EPOCH=1738368000 FORCE_SOURCE_DATE=1
WORKDIR /work
ENTRYPOINT ["resume-compile"]
CMD ["resume.tex"]
