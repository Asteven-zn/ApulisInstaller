FROM ubuntu:18.04
MAINTAINER Jin Li <jin.li@apulis.com>

RUN apt-get update -y && apt-get install -y --no-install-recommends apt-transport-https \
        build-essential \
        cmake \
        git \
        wget \
        vim \
        python-dev \
        python-pip \
        python-yaml \ 
        locales \
        python-pycurl \
        bison \
        curl \
        nfs-common \
        apt-utils \
        screen \
        htop \
        libmysqlclient-dev \
        unixodbc-dev gcc g++ \
        ssh apache2 libapache2-mod-wsgi sudo \
    && pip install --upgrade pip \
    && pip install setuptools \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && pip install flask \
    && pip install flask.restful \
    && pip install requests mysql-connector-python pyodbc tzlocal faulthandler \
    && usermod -a -G sudo www-data \
    && echo "\nwww-data ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers
