ARG version="0.18.1"

# https://github.com/debuerreotype/docker-debian-artifacts
FROM debian:11 AS builder
SHELL ["bash", "-xeuo", "pipefail", "-c"]
WORKDIR /tmp/litecoin

ARG version
ARG gpg_public_key="FE3348877809386C"
ARG gpg_keyserver="keyserver.ubuntu.com"

RUN apt-get update -qq -o=Dpkg::Use-Pty=0 \
    && apt-get install -qq --no-install-suggests --no-install-recommends --yes gnupg curl ca-certificates \
    && gpg --list-keys \
    && gpg --keyserver "${gpg_keyserver}" --recv-keys "${gpg_public_key}" \
    && gpg --fingerprint "${gpg_public_key}" \
    && tarball="litecoin-${version}-x86_64-linux-gnu.tar.gz" \
    && base_url="https://download.litecoin.org/litecoin-${version}" \
    && curl_opts="-O --fail --retry 3 --tlsv1.3" \
    && curl ${curl_opts} "${base_url}/linux/${tarball}.asc" \
    && curl ${curl_opts} "${base_url}/linux/${tarball}" \
    && curl ${curl_opts} "${base_url}/SHA256SUMS.asc" \
    && gpg --verify "${tarball}.asc" "${tarball}" \
    && gpg --verify SHA256SUMS.asc \
    && cat SHA256SUMS.asc | grep "${tarball}" | sha256sum --check --strict --status \
    && tar xvf "${tarball}"

# https://github.com/GoogleContainerTools/distroless/blob/main/cc/README.md
FROM gcr.io/distroless/cc-debian11 as runtime

# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.authors="Hendrik Maus <aidentailor@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/hendrikmaus/litecoin-docker"
LABEL org.opencontainers.image.documentation="https://github.com/hendrikmaus/litecoin-docker/blob/main/README.md"
LABEL org.opencontainers.image.source="https://github.com/hendrikmaus/litecoin-docker/blob/main/Dockerfile"
LABEL org.opencontainers.image.description="UNOFFICIAL Litecoin container image; use at your own risk"

ARG version

USER nonroot # uid 65532
COPY --from=builder "/tmp/litecoin/litecoin-${version}/bin/litecoind" /usr/local/bin/litecoind
VOLUME /usr/share/litecoind/data
CMD ["/usr/local/bin/litecoind"]
