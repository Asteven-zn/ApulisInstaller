FROM ubuntu:18.04
MAINTAINER Deborah Sandoval <Deborah.Sandoval@microsoft.com>

RUN apt-get update && apt-get install -y --no-install-recommends python3.5 python3-pip \
    && pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/ \
    && pip3 config set install.trusted-host mirrors.aliyun.com \
    && pip3 install wheel setuptools requests cachetools tabulate

COPY run.sh /
RUN chmod +x /run.sh

ADD RepairManager /DLWorkspace/src/RepairManager

RUN pip3 install -r /DLWorkspace/src/RepairManager/requirements.txt

CMD /run.sh
