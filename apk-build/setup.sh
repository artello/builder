#!/bin/sh

sed -i '8,11 s/^/#/' /etc/inittab
echo "Artello Builder" > /etc/motd

echo 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

apk update
apk add alpine-sdk s6 postgresql postgresql-contrib redis s3cmd terraform openssh-client

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

STORE_PATH="s3://$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.BUCKET)/packages/"

sudo -u builder ash << EOF
git config --global user.name "Artello Builder"
git config --global user.email "builder@artello.app"

mkdir -p /home/builder/.abuild
mkdir -p /home/builder/.ssh
echo "$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.SSH_PRIVATE_KEY)" > /home/builder/.ssh/id_rsa
echo "$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.SSH_PUBLIC_KEY)" > /home/builder/.ssh/id_rsa.pub
echo "$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.S3_CFG)" > /home/builder/.s3cfg
echo "$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.PRIVATE_KEY)" > /home/builder/.abuild/artello-builder.rsa
echo "$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.PUBLIC_KEY)" > /home/builder/.abuild/artello-builder.rsa.pub
echo 'PACKAGER_PRIVKEY=/home/builder/.abuild/artello-builder.rsa' > /home/builder/.abuild/abuild.conf

ssh-keyscan github.com > /home/builder/.ssh/known_hosts

git clone https://github.com/artello/buildkite-agent ~/buildkite-agent

cd /home/builder/buildkite-agent/.apk/artello/buildkite-agent && abuild checksum && abuild -r

s3cmd put /home/builder/.abuild/artello-builder.rsa.pub $STORE_PATH
EOF

echo "$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.PUBLIC_KEY)" > /etc/apk/keys/artello-builder.rsa.pub

apk update
apk add buildkite-agent