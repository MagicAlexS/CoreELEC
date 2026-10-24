#!/usr/bin/env bash
set -Eeuo pipefail

sudo apt-get update
sudo apt-get install --no-install-recommends -y \
  bash bc bzip2 default-jre-headless diffutils file gawk gcc-12 g++-12 \
  git gperf gzip libc6-dev libjson-perl libncurses5-dev libparse-yapp-perl \
  libxml-parser-perl locales lzop make openssh-client patch patchutils \
  perl python3 rdfind rsync sed tar unzip wget xfonts-utils xsltproc \
  xz-utils zip zstd

sudo locale-gen en_US.UTF-8
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 \
  --slave /usr/bin/cpp cpp /usr/bin/cpp-12 \
  --slave /usr/bin/g++ g++ /usr/bin/g++-12 \
  --slave /usr/bin/gcov gcov /usr/bin/gcov-12
sudo update-alternatives --set gcc /usr/bin/gcc-12

gcc --version
go version
