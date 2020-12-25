FROM ubuntu:18.04

ENV GRAFANA_VERSION=6.7.4 \
    GLIBC_VERSION=2.31 \
    ZLIB_VERSION=1.2.11 \
    OPENSSH_VERSION=8.1p1 \
    OPENSSL_VERSION=1.0.2t

COPY download/glibc-${GLIBC_VERSION}.tar.gz \
    download/zlib-${ZLIB_VERSION}.tar.gz \
    download/openssh-${OPENSSH_VERSION}.tar.gz \
    download/openssl-${OPENSSL_VERSION}.tar.gz \
    /resources/common/

COPY download/grafana_${GRAFANA_VERSION}_amd64.deb \
    download/grafana_${GRAFANA_VERSION}_arm64.deb \
    /resources/grafana/

