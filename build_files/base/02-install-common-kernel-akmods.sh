#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Install Kernel
dnf -y do \
    --action=remove kernel{-core,-modules,-modules-core,-modules-extra,-tools-libs,-tools} \
    --action=install \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm

if [[ "${IMAGE_FLAVOR}" == "dx" ]]; then
  dnf -y install /tmp/kernel-rpms/kernel-devel-*.rpm
fi

dnf5 versionlock add kernel kernel-devel kernel-devel-matched kernel-core kernel-modules kernel-modules-core kernel-modules-extra

dnf -y install /tmp/rpms/{common,kmods}/*xone*.rpm /tmp/rpms/{kmods,common}/*v4l2loopback*.rpm

mkdir -p /etc/pki/akmods/certs
ghcurl "https://github.com/ublue-os/akmods/raw/refs/heads/main/certs/public_key.der" --retry 3 -Lo /etc/pki/akmods/certs/akmods-ublue.der

echo "::endgroup::"
