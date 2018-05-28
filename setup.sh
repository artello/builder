#!/bin/sh

set -e

sed -i '8,11 s/^/#/' /etc/inittab
echo "Artello Builder" > /etc/motd

echo 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

apk update
apk add alpine-sdk s6 jq postgresql postgresql-contrib go redis s3cmd terraform lxd openssh-client bash

keys="
  AWS_BUCKET \
  AWS_CREDENTIALS \
  LXD_REMOTE_URL \
  LXD_REMOTE_NAME \
  LXD_PASSWORD \
  SSH_PRIVATE_KEY \
  SSH_PUBLIC_KEY \
  S3_CFG \
  PRIVATE_KEY \
  PUBLIC_KEY \
"

for k in ${keys}; do
  export ${k}="$(curl -s --unix-socket /dev/lxd/sock x/1.0/config/user.${k})"
done

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

STORE_PATH="s3://$AWS_BUCKET/packages/"
HOME=/home/builder
ABUILD=$HOME/.abuild

sudo -u builder ash << EOF
git config --global user.name "Artello Builder"
git config --global user.email "builder@artello.app"

cd $HOME

echo "--- Setup Terraform"

mkdir -p $HOME/.terraform.d/plugins/linux_amd64
go get -v -u github.com/sl1pm4t/terraform-provider-lxd
mv $HOME/go/bin/terraform-provider-lxd ~/.terraform.d/plugins/linux_amd64/terraform-provider-lxd

echo "--- Setup LXD"

lxc remote add $LXD_REMOTE_NAME $LXD_REMOTE_URL --password $LXD_PASSWORD --accept-certificate
lxc remote set-default $LXD_REMOTE_NAME

echo "--- Setup Builder"

mkdir -p $ABUILD
mkdir -p $HOME/.ssh
mkdir -p $HOME/.aws

echo "$SSH_PRIVATE_KEY" > $HOME/.ssh/id_rsa
echo "$SSH_PUBLIC_KEY" > $HOME/.ssh/id_rsa.pub
echo "$S3_CFG" > $HOME/.s3cfg
echo "$AWS_CREDENTIALS" > $HOME/.aws/credentials
echo "$PRIVATE_KEY" > $ABUILD/artello-builder.rsa
echo "$PUBLIC_KEY" > $ABUILD/artello-builder.rsa.pub
echo 'PACKAGER_PRIVKEY=$ABUILD/artello-builder.rsa' > $ABUILD/abuild.conf

ssh-keyscan github.com > $HOME/.ssh/known_hosts

chmod 600 $HOME/.ssh/id_rsa

git clone https://github.com/artello/buildkite-agent ~/buildkite-agent

cd $HOME/buildkite-agent/.apk/artello/buildkite-agent && abuild checksum && abuild -r

s3cmd put $ABUILD/artello-builder.rsa.pub $STORE_PATH
EOF

echo "$PUBLIC_KEY" > /etc/apk/keys/artello-builder.rsa.pub

apk update
apk add buildkite-agent
rm -rf $HOME/packages/artello