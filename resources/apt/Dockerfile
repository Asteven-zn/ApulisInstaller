FROM ubuntu:bionic-20190122 as ubuntu_18_04_1

ADD sources.list /etc/apt/sources.list

RUN apt update && \
    apt upgrade -y && \
    apt install -d -y ansible && \
    cd /var/cache/apt/archives && mv *.deb /tmp/ && \
    apt-get install -d -y chrony && mv *.deb /tmp/ && \
    apt-get install -d -y nfs-common nfs-kernel-server && mv *.deb /tmp/ && \
    apt-get install -d -y ansible && mv *.deb /tmp/ && \
    apt-get install -d -y openssl && mv *.deb /tmp/ && \
