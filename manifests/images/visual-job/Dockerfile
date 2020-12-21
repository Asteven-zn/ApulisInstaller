FROM ubuntu:18.04
RUN apt-get update -y \
    && umask 022 \
    && apt-get install -y python3-pip \
    && python3 -m pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ \
    && python3 -m pip install --upgrade pip \
    && python3 -m pip install tensorboard \
    && mkdir -p /data/tensorborad-log
CMD ["/bin/sh" "-c" "sleep infinity"]