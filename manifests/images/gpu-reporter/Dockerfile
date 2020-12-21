FROM python:3.7

RUN pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/ \
    && pip3 config set install.trusted-host mirrors.aliyun.com \
    && pip3 install requests flask prometheus_client flask-cors

WORKDIR /gpu-reporter

COPY * /gpu-reporter/
