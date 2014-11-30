# docker build --tag='synchzor/synchzor' .

FROM ubuntu:14.04
# FROM debian:sid
MAINTAINER Evan Tahler <evantahler@gmail.com>

# ENV AWSACCESSKEYID     your_s3_key
# ENV AWSSECRETACCESSKEY your_secret_key
# ENV S3_BUCKET          your_bucket

# INSTALL BASICS
RUN apt-get update
RUN apt-get -y install \
  python-software-properties \
  software-properties-common \
  libfuse-dev \
  fuse \
  build-essential \
  git \
  libcurl4-openssl-dev \
  libxml2-dev \
  mime-support \
  automake \
  libssl-dev \
  pkg-config \
  curl \
  libtool \
  wget \
  htop \
  nodejs \
  npm

# LINK NODE
RUN ln -s /usr/bin/nodejs /usr/bin/node
RUN /usr/bin/npm install bittorrent-sync

# BUILD FUSE-S3
RUN mkdir /tmp/fuse
RUN git clone https://github.com/s3fs-fuse/s3fs-fuse /tmp/fuse
RUN cd /tmp/fuse && ./autogen.sh
RUN cd /tmp/fuse && ./configure --prefix=/usr --with-openssl
RUN cd /tmp/fuse && make
RUN cd /tmp/fuse && make install
RUN mkdir /s3bucket

# INSTALL BTSYNC
RUN curl -o /usr/bin/btsync.tar.gz http://download-new.utorrent.com/endpoint/btsync/os/linux-x64/track/stable
RUN cd /usr/bin && tar -xzvf btsync.tar.gz && rm btsync.tar.gz
ADD ./config/btsync.conf /btsync/btsync.conf
RUN mkdir -p /tmp/btsync

# OPEN PORTS
EXPOSE 55555
EXPOSE 8000

# SET UP SUPERVISOR
ADD ./config/boot.sh /boot.sh

# RUN
CMD ["/bin/bash", "/boot.sh"]