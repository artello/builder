#!/bin/sh

set -e

echo "Artello Builder" > /etc/motd

echo 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

apk update
apk add alpine-sdk \
        curl \
        s6 \
        jq \
        postgresql \
        postgresql-contrib \
        linux-headers \
        go \
        terraform \
        redis \
        shadow \
        openssh-client \
        bash \
        python \
        py-crcmod

curl --output google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-222.0.0-linux-x86_64.tar.gz
tar -xvf google-cloud-sdk.tar.gz -C /var/lib

go get -v -u github.com/googlecloudplatform/gcsfuse
mv $HOME/go/bin/gcsfuse /usr/bin/gcsfuse

rc-update add s6
rc-update add s6-svscan
rc-update add postgresql
rc-update add redis

adduser --disabled-password --gecos "" builder
echo 'builder ALL=(ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo

addgroup builder abuild
mkdir -p /var/cache/distfiles
chgrp abuild /var/cache/distfiles
chmod g+w /var/cache/distfiles
echo '/home/builder/packages/artello' >> /etc/apk/repositories
