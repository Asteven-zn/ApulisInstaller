#! /bin/sh

GRAFANA_VERSION=6.7.4
GLIBC_VERSION=2.31
ZLIB_VERSION=1.2.11
OPENSSH_VERSION=8.1p1
OPENSSL_VERSION=1.0.2t

HARBOR=harbor.apulis.cn

mkdir -p download

echo "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb"
curl https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb > download/grafana_${GRAFANA_VERSION}_amd64.deb \
  || { echo "[ERROR] downloading grafana_${GRAFANA_VERSION}_amd64.deb failed"; exit 1; }

echo "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_arm64.deb"
curl https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_arm64.deb > download/grafana_${GRAFANA_VERSION}_arm64.deb \
  || { echo "[ERROR] downloading grafana_${GRAFANA_VERSION}_arm64.deb failed"; exit 1; }

echo "http://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz"
curl http://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz > download/glibc-${GLIBC_VERSION}.tar.gz \
  || { echo "[ERROR] downloading glibc-${GLIBC_VERSION}.tar.gz failed"; exit 1; }

echo "https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
curl https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz > download/zlib-${ZLIB_VERSION}.tar.gz \
  || { echo "[ERROR] downloading zlib-${ZLIB_VERSION}.tar.gz failed"; exit 1; }

echo "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VERSION}.tar.gz"
curl https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VERSION}.tar.gz > download/openssh-${OPENSSH_VERSION}.tar.gz \
  || { echo "[ERROR] downloading openssh-${OPENSSH_VERSION}.tar.gz failed"; exit 1; }

echo "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
curl https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz > download/openssl-${OPENSSL_VERSION}.tar.gz \
  || { echo "[ERROR] downloading openssl-${OPENSSL_VERSION}.tar.gz failed"; exit 1; }

docker build -t ${HARBOR}/common/build-resources:latest .
#docker push ${HARBOR}/common/build-resources:latest