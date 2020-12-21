FROM ubuntu:18.04 as builder

RUN  sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
     && apt-get clean \
     && apt-get update && apt-get install -y wget gzip build-essential \
          net-tools inetutils-traceroute iputils-ping

WORKDIR /ssh_build

ENV DIST_DIR=/ssh_build/dist ROOT=/ssh_build/root BUILD_DIR=/ssh_build/build

RUN mkdir -p $DIST_DIR $ROOT $BUILD_DIR
# make it cache friendly
COPY download/glibc-2.31.tar.gz download/zlib-1.2.11.tar.gz download/openssh-8.1p1.tar.gz download/openssl-1.0.2t.tar.gz $DIST_DIR
COPY build_zlib.sh /ssh_build
RUN sh build_zlib.sh
COPY build_openssl.sh /ssh_build
RUN sh build_openssl.sh
COPY build_ssh.sh /ssh_build/
RUN sh build_ssh.sh

# compile gpu_topo
WORKDIR /gpu_topo_build
COPY gpu_topo.cpp /gpu_topo_build
RUN g++ -o gpu_topo gpu_topo.cpp

FROM python:3.8.0-alpine3.10

WORKDIR /dlts-init
COPY requirements.txt /dlts-init

RUN pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/ \
     && pip3 config set install.trusted-host mirrors.aliyun.com \
     && pip3 install -r /dlts-init/requirements.txt

COPY --from=builder /ssh_build/root /dlts-init/ssh_build
COPY --from=builder /gpu_topo_build/gpu_topo /dlts-init/gpu_topo

COPY install.sh init.sh /dlts-init/
COPY ssh_config /dlts-init/ssh_config
COPY runtime /dlts-init/runtime
