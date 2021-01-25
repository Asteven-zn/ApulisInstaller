FROM ubuntu:bionic-20190122 as ubuntu_18_04_1

ADD sources.list /etc/apt/sources.list

RUN apt update && \
    apt install -y software-properties-common && \
    apt-add-repository --yes --update ppa:ansible/ansible && \
    apt update && \
    apt install -d -y \
      conntrack && \
    cd /var/cache/apt/archives && \
    tar zcvf /tmp/basic_bionic.tar.gz *.deb && rm -rf * && \
    apt install -d -y ansible && tar zcvf /tmp/ansible_bionic.tar.gz *.deb && rm -rf * && \
    apt install -d -y nfs-common nfs-kernel-server && tar zcvf /tmp/nfs_bionic.tar.gz *.deb && rm -rf * && \
    apt install -d -y chrony && tar zcvf /tmp/chrony_bionic.tar.gz *.deb && rm -rf * && \
    apt install -d -y python-pip && tar zcvf /tmp/python2_bionic.tar.gz *.deb && rm -rf * && \
    apt install -d -y python3-pip && tar zcvf /tmp/python3_bionic.tar.gz *.deb && rm -rf *

# storing packages on alpine
FROM alpine:3.9

ENV SYS_PKG_VER=0.3.3

COPY --from=ubuntu_18_04_1 /tmp/*.tar.gz /packages/

CMD [ "sleep", "360000000" ]
