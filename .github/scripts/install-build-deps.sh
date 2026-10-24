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

# Hosted runners already register cpp as an independent alternatives group.
# Select GCC 12 through this job's PATH without changing those global groups.
host_tools="${RUNNER_TEMP:?RUNNER_TEMP is required}/coreelec-host-tools"
mkdir -p "${host_tools}"
for tool in gcc g++ cpp gcov; do
  ln -sfn "/usr/bin/${tool}-12" "${host_tools}/${tool}"
done
printf '%s\n' "${host_tools}" >> "${GITHUB_PATH:?GITHUB_PATH is required}"
export PATH="${host_tools}:${PATH}"

gcc --version
go version
