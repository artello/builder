#!/bin/sh

set -e

echo "Artello Builder" > /etc/motd

echo 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

apk update
apk add alpine-sdk s6 jq postgresql postgresql-contrib go redis terraform lxd openssh-client bash python

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
